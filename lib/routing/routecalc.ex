defmodule Routing.Routecalc do
  require Logger
  use Timex

  alias Routing.Graphrepo
  alias Routing.Routerepo
  alias Routing.Droneportrepo
  alias Routing.Dronerepo

  def setup do
    case GenServer.start(Graphrepo, Graph.new, name: :graphrepo) do
      {:ok, _} ->
        Logger.info("Graphhandler started.")
      {:error, {:already_started, _}} ->
        # NOTE it is not known why it would ever take that branch,
        # but it occured during performance test
        Logger.info("Graphhandler already started ...")
    end
  end

  def calc(data, delivery) do
    case GenServer.whereis(:graphrepo) do
      nil ->
        setup()
        calc(data, delivery)
      _ ->
        from = Map.get(data, "from")
        to = Map.get(data, "to")

        data = case decide_on_method(delivery) do
          :direct ->
            build_map([atom("dp#{from}"), atom("dp#{to}")], false)
          :delivery ->
            case GenServer.call(:graphrepo, {:get_graph_delivery, from, to}) do
              {:err, message} ->
                raise message
              {graph, start_building, target_building} ->
                perform_calculation(graph, start_building, target_building, true)
            end
          :dumb ->
            case GenServer.call(:graphrepo, {:get_graph_delivery, from, to}) do
              {:err, message} ->
                raise message
              {graph, start_building, target_building} ->
                {:ok, ideal} = Graph.shortest_path(graph, atom("dp#{start_building}"), atom("dp#{target_building}"))
                ideal = complete_route_dumb(graph, ideal, start_building, target_building)
                build_map(ideal, true)
            end
        end
        data
    end
  end

  defp decide_on_method(delivery) do
    case delivery do
      :delivery -> :delivery
      :distribution -> :direct
      :dumb -> :dumb
    end
  end

  def perform_calculation(init_graph, start_building, target_building, delivery) do
    perform_calculation(init_graph, start_building, target_building, delivery, {nil, nil, nil, nil, false})
  end
  def perform_calculation(init_graph, start_building, target_building, delivery, {old_route, old_ranking, old_score, old_timediff, old_accept} = previous) do
    case edge_hop_processing(init_graph, atom("dp#{start_building}"), :start) do
      {:err, message} ->
        Logger.info("Shop not reachable")
        raise message
      {graph, start_hops} ->
        Logger.debug("Shop reachability confirmed")
        graph = graph
        start_hops = start_hops
    end
    {:ok, ideal} = Graph.shortest_path(graph, atom("dp#{start_building}"), atom("dp#{target_building}"))
    tryroute = build_map(ideal, delivery) |> Routerepo.try_route(true)

    # TODO use config variable for time format
    {graph, end_hops} = edge_hop_processing(graph, atom("dp#{target_building}"), :end, Timex.parse!(Enum.at(tryroute, -1)[:arr_time], "{ISO:Extended}"))

    {graph, start_hops, end_hops} = correct_start_target_connection(graph, atom("dp#{start_building}"), atom("dp#{target_building}"), start_hops, end_hops)
    {:ok, ideal} = Graph.shortest_path(graph, atom("dp#{start_building}"), atom("dp#{target_building}"))
    ideal = complete_route(ideal, start_hops, end_hops)
    tryroute = build_map(ideal, delivery) |> Routerepo.try_route(false)

    ranking = get_factors(tryroute["hop/_route"], start_building, target_building) |> Enum.sort_by(&(elem(&1, 1)))
    timediff = Enum.at(tryroute["hop/_route"], -1)["hop/endtime"] - Enum.at(tryroute["hop/_route"], 0)["hop/starttime"]
    score = Enum.count(ranking, fn(x) -> elem(x, 1) < 0 end) + 1
    accept = Enum.count(ranking, fn(x) -> elem(x, 1) == -20 end) == 0

    # IO.puts("--------")
    # IO.puts("Route:")
    # IO.puts(" Old: #{Kernel.inspect(old_route)} \n vs \n New: #{Kernel.inspect(ideal)}")
    # IO.puts("Ranking:")
    # IO.puts(" Old: #{Kernel.inspect(old_ranking)} \n vs \n New: #{Kernel.inspect(ranking)}")
    # IO.puts("Score:")
    # IO.puts(" Old: #{Kernel.inspect(old_score)} \n vs \n New: #{Kernel.inspect(score)}")
    # IO.puts("Timediff:")
    # IO.puts(" Old: #{Kernel.inspect(old_timediff)} \n vs \n New: #{Kernel.inspect(timediff)}")
    # IO.puts("Accepted:")
    # IO.puts(" Old: #{Kernel.inspect(old_accept)} \n vs \n New: #{Kernel.inspect(accept)}")
    # IO.puts("--------")

    case previous do
      {nil, nil, nil, nil, false} ->
        cond do
          Enum.empty?(ranking) && accept ->
            build_map(ideal, delivery)
          score > 1 ->
            perform_calculation(init_graph, start_building, target_building, delivery, {ideal, ranking, score, timediff, accept})
          accept ->
            build_map(ideal, delivery)
          true ->
            raise "Route calculation reached unknown state"
        end
      {_, _, _, _, _} ->
        if timediff <= old_timediff * (1+old_score/10) && score < old_score do
          perform_calculation(init_graph, start_building, target_building, delivery, {ideal, ranking, score, timediff, accept})
        else
          case old_ranking do
            [] ->
              cond do
                accept ->
                  old_route |> build_map(delivery)
                !accept ->
                  raise "No efficient route was found"
              end
            _ ->
              {to_delete, old_ranking} = Enum.split(old_ranking, 1)
              init_graph = GenServer.call(:graphrepo, {:delete_nodes, Keyword.keys(to_delete), init_graph})
              perform_calculation(init_graph, start_building, target_building, delivery, {old_route, old_ranking, old_score, old_timediff, old_accept})
          end
        end
    end
  rescue
    e in MatchError ->
      if old_route != nil && old_accept do
        old_route |> build_map(delivery)
      else
        raise "No efficient route was found"
      end
  end

  # Requires from and to to be in :dp<number> format
  def edge_hop_processing(graph, target, type, time \\ Timex.now) do
    case get_edge_hop_pairs(graph, target, type, time) do
      {:ok, pairs, unreachable_targets} ->
        graph = GenServer.call(:graphrepo, {:update_edges, pairs, target, graph})
        graph = GenServer.call(:graphrepo, {:delete_edges, unreachable_targets, target, graph})
        {graph, pairs}
      {:err, message} ->
        {:err, message <> target}
    end
  end

  def get_edge_hop_pairs(graph, id, type, time) do
    case graph.edges |> Map.get(id) do
      nil ->
        {:err, "Target unreachable"}
      neighbors ->
        neighbors = neighbors
                    |> MapSet.to_list
                    |> Map.new(fn(x) -> {x[:to], x[:costs]} end)
        predictions = neighbors
                      |> Map.keys
                      |> Droneportrepo.get_predictions_for(Timex.to_unix(time))
        {pairs, unreachable} = get_pairs(Map.keys(neighbors), Map.keys(predictions), neighbors, predictions, type) |> filter_for_best_option
        {:ok, pairs, unreachable}
    end
  end

  defp get_pairs([], _p, _neighbors, _predictions, _type), do: %{}
  defp get_pairs([h | t], p, neighbors, predictions, type) do
    Map.merge(get_pairs(t, p, neighbors, predictions, type), %{h => match(p, h, neighbors, predictions, type)})
  end

  defp match([], _to, _neighbors, _predictions, _type), do: []
  defp match([h | t], to, neighbors, predictions, type) do
    # TODO consider a different approach for cost calculation where costs do not skyrocket
    # NOTE differenciating here is important because end hops have taking and giving switched around
    {takefac, givefac} = case type do
      :start ->
        {Droneportrepo.get_predicted_cost_factor(predictions, h, :take),
          Droneportrepo.get_predicted_cost_factor(predictions, to, :give)}
      :end ->
        {Droneportrepo.get_predicted_cost_factor(predictions, h, :give),
          Droneportrepo.get_predicted_cost_factor(predictions, to, :take)}
    end
    result = if neighbors[h] + neighbors[to] < Dronerepo.get_dronerange(0) do
      [%{from: h,
        costs: neighbors[h] * takefac + neighbors[to] * givefac,
        dist_to: neighbors[to],
        dist_from: neighbors[h],
        costs_to: neighbors[to] * givefac,
        costs_from: neighbors[h] * takefac}]
    else
      []
    end
    Enum.concat(match(t, to, neighbors, predictions, type), result)
  end

  defp filter_for_best_option(pairs) do
    do_filter(Map.keys(pairs), pairs)
  end
  defp do_filter([], _pairs), do: {%{}, []}
  defp do_filter([key | t], pairs) do
    {p, tr} = do_filter(t, pairs)
    case Map.get(pairs, key) do
      [] ->
        {p, Enum.concat(tr, [key])}
      options ->
        best = options |> Enum.min_by(fn(x) -> x[:costs] end)
        {Map.merge(p, %{key => best}), tr}
    end
  end

  defp correct_start_target_connection(graph, start, target, start_hops, end_hops) do
    in_start = Map.keys(start_hops) |> Enum.member?(target)
    in_end   = Map.keys(end_hops) |> Enum.member?(start)
    result = case {in_start, in_end} do
      {false, true} ->
        end_hops = Map.delete(end_hops, start)
        graph = GenServer.call(:graphrepo, {:delete_edges, [start], target, graph})
        {graph, start_hops, end_hops}
      {true, false} ->
        start_hops = Map.delete(start_hops, target)
        graph = GenServer.call(:graphrepo, {:delete_edges, [start], target, graph})
        {graph, start_hops, end_hops}
      {true, true} ->
        if start_hops[target][:dist_from] + start_hops[target][:dist_to] + end_hops[start][:dist_from] < Dronerepo.get_dronerange(0) do
          # Costs from hive to shop + from hive to cust + from cust to hive
          costs = start_hops[target][:costs_from] + start_hops[target][:dist_to] + end_hops[start][:costs_from]
          graph = GenServer.call(:graphrepo, {:update_edges, %{start => %{costs: costs}}, target, graph})
        else
          start_hops = Map.delete(start_hops, target)
          end_hops = Map.delete(end_hops, start)
          graph = GenServer.call(:graphrepo, {:delete_edges, [start], target, graph})
        end
        {graph, start_hops, end_hops}
      {false, false} ->
        {graph, start_hops, end_hops}
    end
    result
  end

  defp complete_route(route, start_hops, end_hops) do
    add_edge_hops(route, start_hops, :start) |> add_edge_hops(end_hops, :end)
  end

  defp complete_route_dumb(graph, route, start, target) do
    sid = atom("dp#{start}")
    tid = atom("dp#{target}") 
    first_edge = Graph.get_edge(graph, Enum.at(route, 0), Enum.at(route, 1))
    start = graph.edges[sid]
            |> MapSet.to_list
            |> Enum.filter(fn(x) -> (x[:costs] + first_edge[:costs]) < Dronerepo.get_dronerange(0) end)
            |> Enum.filter(fn(x) -> x[:to] != tid end)
            |> Enum.at(0)
    last_edge = Graph.get_edge(graph, Enum.at(route, -2), Enum.at(route, -1))
    last = graph.edges[tid]
           |> MapSet.to_list
           |> Enum.filter(fn(x) -> (x[:costs] + last_edge[:costs]) < Dronerepo.get_dronerange(0) end)
           |> Enum.filter(fn(x) -> x[:to] != sid end)
           |> Enum.at(0)
    Enum.concat([start[:to]], route) |> Enum.concat([last[:to]])
  end

  def add_edge_hops(route, edge_hops, :start), do: [edge_hops[Enum.at(route, 1)][:from]] ++ route
  def add_edge_hops(route, edge_hops, :end), do: route ++ [edge_hops[Enum.at(route, -2)][:from]]

  def get_factors([], _start, _target), do: []
  def get_factors([prev | [h | _t] = next], start, target) do
    hid = atom("dp#{h["hop/end"]["db/id"]}")
    cond do
      h["hop/end"]["db/id"] == target ->
        get_factors([], start, target)
      h["hop/start"]["db/id"] == start ->
          costs = [hid]
                  |> Droneportrepo.get_predictions_for(h["hop/endtime"])
                  |> Droneportrepo.pass_packet_costs(hid, prev["hop/distance"] + h["hop/distance"])
        Enum.concat([{hid, costs}], get_factors(next, start, target))
      true ->
        costs = [hid]
                |> Droneportrepo.get_predictions_for(h["hop/endtime"])
                |> Droneportrepo.pass_packet_costs(hid, h["hop/distance"])
        Enum.concat([{hid, costs}], get_factors(next, start, target))
    end
  end

  # TODO make private
  # Looks like this in the end:
  # %{is_delivery: true/false, route: [%{from: "id", to: "id"}]}
  def build_map(route, delivery) do
    start_time = Timex.shift(Timex.now, [hours: 1])
    %{is_delivery: delivery, time: start_time, route: do_build_map(route)}
  end
  defp do_build_map([_from | []]), do: []
  defp do_build_map([from | [to | _] = next]) do
    from = Regex.replace(~r/[A-Za-z]*/, "#{from}", "") |> String.to_integer
    to   = Regex.replace(~r/[A-Za-z]*/, "#{to}", "") |> String.to_integer
    [%{from: from, to: to}] ++ do_build_map(next)
  end

  def atom(name) do
    String.to_existing_atom(name)
  rescue
    ArgumentError -> String.to_atom(name)
  end
end

