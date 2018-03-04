defmodule Routing.Routecalc do
  require Logger
  use Timex

  alias Routing.Graphrepo
  alias Routing.Routerepo
  alias Routing.Droneportrepo
  alias Routing.Dronerepo

  def setup do
    # {:ok, _} = GenServer.start_link(Graphrepo, Graph.new, name: :graphrepo)
    # Logger.info("Graphhandler started.")
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
            build_map([:"dp#{from}", :"dp#{to}"], false)
          :delivery ->
            {graph, start_building, target_building} = GenServer.call(:graphrepo, {:get_graph_delivery, from, to})
            perform_calculation(graph, start_building, target_building, true)
          :dumb ->
            {graph, start_building, target_building} = GenServer.call(:graphrepo, {:get_graph_delivery, from, to})
            ideal = Graph.shortest_path(graph, :"dp#{start_building}", :"dp#{target_building}")
            build_map(ideal, true)
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
    perform_calculation(init_graph, start_building, target_building, delivery, {nil, nil, nil, nil})
  end
  def perform_calculation(init_graph, start_building, target_building, delivery, {old_route, old_ranking, old_score, old_timediff} = previous) do
    {graph, start_hops} = edge_hop_processing(init_graph, :"dp#{start_building}", :start)
    ideal = Graph.shortest_path(graph, :"dp#{start_building}", :"dp#{target_building}")
    tryroute = build_map(ideal, delivery)
    tryroute = Routerepo.try_route(tryroute, true)

    # TODO use config variable for time format
    {graph, end_hops} = edge_hop_processing(graph, :"dp#{target_building}", :end, Timex.parse!(Enum.at(tryroute, -1)[:arr_time], "{ISO:Extended}"))
    ideal = Graph.shortest_path(graph, :"dp#{start_building}", :"dp#{target_building}")
    tryroute = complete_route(ideal, start_hops, end_hops) |> build_map(delivery) |> Routerepo.try_route

    {graph, start_hops, end_hops} = correct_start_target_connection(graph, :"dp#{start_building}", :"dp#{target_building}", start_hops, end_hops)
    ideal = Graph.shortest_path(graph, :"dp#{start_building}", :"dp#{target_building}") |> complete_route(start_hops, end_hops)
    tryroute = build_map(ideal, delivery) |> Routerepo.try_route
    ranking = get_factors(tryroute["hop/_route"], start_building, target_building) |> Enum.sort_by(&(elem(&1, 1)))
    timediff = Enum.at(tryroute["hop/_route"], -1)["hop/endtime"] - Enum.at(tryroute["hop/_route"], 0)["hop/starttime"]
    score = Enum.count(ranking, fn(x) -> elem(x, 1) < 0 end) + 1

    case previous do
      {nil, nil, nil, nil} ->
        cond do
          Enum.empty?(ranking) ->
            build_map(ideal, delivery)
          score > 1 ->
            perform_calculation(init_graph, start_building, target_building, delivery, {ideal, ranking, score, timediff})
          true ->
            build_map(ideal, delivery)
        end
      {_, _, _, _} ->
        if timediff <= old_timediff * (1+old_score/10) && score <= old_score do
          perform_calculation(init_graph, start_building, target_building, delivery, {ideal, ranking, score, timediff})
        else
          case old_ranking do
            [] ->
              old_route
            _ ->
              {to_delete, old_ranking} = Enum.split(old_ranking, 1)
              init_graph = GenServer.call(:graphrepo, {:delete_nodes, Keyword.keys(to_delete), graph})
              perform_calculation(init_graph, start_building, target_building, delivery, {old_route, old_ranking, old_score, old_timediff})
          end
        end
    end
  end

  # Requires from and to to be in :dp<number> format
  def edge_hop_processing(graph, target, type, time \\ Timex.now) do
    {pairs, unreachable_targets} = get_edge_hop_pairs(graph, target, type, time)
    graph = GenServer.call(:graphrepo, {:update_edges, pairs, target, graph})
    graph = GenServer.call(:graphrepo, {:delete_edges, unreachable_targets, target, graph})
    {graph, pairs}
  end

  def get_edge_hop_pairs(graph, id, type, time) do
    neighbors = graph.edges |> Map.get(id) |> MapSet.to_list |> Map.new(fn(x) -> {x[:to], x[:costs]} end)
    predictions = Map.keys(neighbors) |> Droneportrepo.get_predictions_for(Timex.to_unix(time))
    get_pairs(Map.keys(neighbors), Map.keys(predictions), neighbors, predictions, type) |> filter_for_best_option
  end

  defp get_pairs([], _p, _neighbors, _predictions, _type), do: %{}
  defp get_pairs([h | t], p, neighbors, predictions, type) do
    Map.merge(get_pairs(t, p, neighbors, predictions, type), %{h => match(p, h, neighbors, predictions, type)})
  end

  defp match([], _to, _neighbors, _predictions, _type), do: []
  defp match([h | t], to, neighbors, predictions, type) do
    # TODO consider a different approach for cost calculation where costs do not skyrocket (see pictre in WhatsApp)
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
    # best = Map.get(pairs, key) |> Enum.min_by(fn(x) -> x[:costs] end)
    {p, tr} = do_filter(t, pairs)
    case Map.get(pairs, key) do
      [] ->
        {p, Enum.concat(tr, [key])}
      options ->
        best = Map.get(pairs, key) |> Enum.min_by(fn(x) -> x[:costs] end)
        {Map.merge(p, %{key => best}), tr}
    end
  end

  defp correct_start_target_connection(graph, start, target, start_hops, end_hops) do
    in_start = Map.keys(start_hops) |> Enum.member?(target)
    in_end   = Map.keys(end_hops) |> Enum.member?(start)
    case {in_start, in_end} do
      {false, true} ->
        end_hops = Map.delete(end_hops, start)
        graph = GenServer.call(:graphrepo, {:delete_edges, [start], target, graph})
      {true, false} ->
        start_hops = Map.delete(start_hops, target)
        graph = GenServer.call(:graphrepo, {:delete_edges, [start], target, graph})
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
      {false, false} ->
        false
    end
    {graph, start_hops, end_hops}
  end

  defp complete_route(route, start_hops, end_hops) do
    add_edge_hops(route, start_hops, :start) |> add_edge_hops(end_hops, :end)
  end

  def add_edge_hops(route, edge_hops, :start), do: [edge_hops[Enum.at(route, 1)][:from]] ++ route
  def add_edge_hops(route, edge_hops, :end), do: route ++ [edge_hops[Enum.at(route, -2)][:from]]

  def get_factors([], _start, _target), do: []
  def get_factors([prev | [h | t] = next], start, target) do
    previd = :"dp#{prev["hop/end"]["db/id"]}"
    hid = :"dp#{h["hop/end"]["db/id"]}"
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
    start_time = Timex.shift(Timex.now, [hours: 1, seconds: 5]) # Five seconds delay for a route to be flown
    %{is_delivery: delivery, time: start_time, route: do_build_map(route)}
  end
  defp do_build_map([_from | []]), do: []
  defp do_build_map([from | [to | _] = next]) do
    from = Regex.replace(~r/[A-Za-z]*/, "#{from}", "") |> String.to_integer
    to   = Regex.replace(~r/[A-Za-z]*/, "#{to}", "") |> String.to_integer
    [%{from: from, to: to}] ++ do_build_map(next)
  end
end

