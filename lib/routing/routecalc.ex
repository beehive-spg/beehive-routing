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
        # NOTE it is not known why it would ever take that branch, but it
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

        data = case decide_on_method(delivery, from, to) do
          :direct ->
            build_map([:"dp#{from}", :"dp#{to}"], false)
          method ->
            {graph, start_building, target_building} = GenServer.call(:graphrepo, {:"get_graph_#{method}", from, to})

            {graph, start_hops} = edge_hop_processing(graph, :"dp#{start_building}")

            ideal = Graph.shortest_path(graph, :"dp#{start_building}", :"dp#{target_building}")
            tryroute = build_map(ideal, delivery)
            tryroute = Routerepo.try_route(tryroute, true)

            # TODO use config variable for time format
            {graph, end_hops} = edge_hop_processing(graph, :"dp#{target_building}", Timex.parse!(Enum.at(tryroute, -1)[:arr_time], "{ISO:Extended}"))

            ideal = Graph.shortest_path(graph, :"dp#{start_building}", :"dp#{target_building}")
            tryroute = complete_route(ideal, start_hops, end_hops) |> build_map(delivery) |> Routerepo.try_route

            fac_map = get_factors(tryroute["hop/_route"], graph)
            # fac_map
            build_map(ideal, delivery)
        end
        data
    end
  end

  defp decide_on_method(delivery, from, to) do
    cond do
      delivery ->
        :delivery
      !delivery ->
        case Routerepo.is_reachable(from, to) do
          true ->
            :direct
          false ->
            :distribution
        end
    end
  end

  # Requires from and to to be in :dp<number> format
  def edge_hop_processing(graph, target, time \\ Timex.now) do
    {pairs, unreachable_targets} = get_edge_hop_pairs(graph, target, time)
    graph = GenServer.call(:graphrepo, {:update_edges, pairs, target, graph})
    graph = GenServer.call(:graphrepo, {:delete_edges, unreachable_targets, target, graph})
    {graph, pairs}
  end

  def get_edge_hop_pairs(graph, id, time) do
    neighbors = graph.edges |> Map.get(id) |> MapSet.to_list |> Map.new(fn(x) -> {x[:to], x[:costs]} end)
    predictions = Map.keys(neighbors) |> Droneportrepo.get_predictions_for(Timex.to_unix(time))
    get_pairs(Map.keys(neighbors), Map.keys(predictions), neighbors, predictions) |> filter_for_best_option
  end

  defp get_pairs([], _p, _neighbors, _predictions), do: %{}
  defp get_pairs([h | t], p, neighbors, predictions) do
    Map.merge(get_pairs(t, p, neighbors, predictions), %{h => match(p, h, neighbors, predictions)})
  end

  defp match([], _to, _neighbors, _predictions), do: []
  defp match([h | t], to, neighbors, predictions) do
    # TODO consider a different approach for cost calculation where costs do not skyrocket (see pictre in WhatsApp)
    takefac = Droneportrepo.get_predicted_cost_factor(predictions, h, :take)
    givefac = Droneportrepo.get_predicted_cost_factor(predictions, to, :give)
    result = if neighbors[h] + neighbors[to] < Dronerepo.get_dronerange(0) do
      [%{from: h, costs: neighbors[h] * takefac + neighbors[to] * givefac}]
    else
      []
    end
    Enum.concat(match(t, to, neighbors, predictions), result)
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

  defp complete_route(route, start_hops, end_hops) do
    add_edge_hops(route, start_hops, :start) |> add_edge_hops(end_hops, :end)
  end

  def add_edge_hops(route, edge_hops, :start), do: [edge_hops[Enum.at(route, 1)][:from]] ++ route
  def add_edge_hops(route, edge_hops, :end), do: route ++ [edge_hops[Enum.at(route, -2)][:from]]

  def get_factors(route, _graph) do
    hop = Enum.at(route, 1)
    id = :"dp#{hop["hop/end"]["db/id"]}"
    costs = [id]
            |> Droneportrepo.get_predictions_for(hop["hop/endtime"])
            |> Droneportrepo.pass_packet_costs(id, Enum.at(route, 0)["hop/distance"] + hop["hop/distance"])

    [{id, costs}] ++ do_get_factors(Enum.slice(route, 2..-3))
  end
  def do_get_factors([]), do: []
  def do_get_factors([h | t]) do
    id = :"dp#{h["hop/end"]["db/id"]}"
    costs = [id]
            |> Droneportrepo.get_predictions_for(h["hop/endtime"])
            |> Droneportrepo.pass_packet_costs(id, h["hop/distance"])
    [{id, costs}] ++ do_get_factors(t)
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

