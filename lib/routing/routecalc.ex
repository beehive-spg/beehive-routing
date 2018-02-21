defmodule Routing.Routecalc do
  require Logger
  use Timex

  alias Routing.Graphrepo
  alias Routing.Routerepo
  alias Routing.Droneportrepo

  def setup do
    {:ok, _} = GenServer.start_link(Graphrepo, Graph.new, name: :graphrepo)
    Logger.info("Graphhandler started.")
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
            tryroute = build_map(ideal, delivery) |> Routerepo.get_real_data |> Routerepo.try_route
            # TODO use config variable for time format
            {graph, end_hops} = edge_hop_processing(graph, :"dp#{target_building}", Timex.parse!(Enum.at(tryroute, -1)[:arr_time], "{ISO:Extended}"))
            ideal = Graph.shortest_path(graph, :"dp#{start_building}", :"dp#{target_building}")
            ideal = add_edge_hops(ideal, start_hops, :start)
            ideal = add_edge_hops(ideal, end_hops, :end)
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
    pairs = get_edge_hop_pairs(graph, target, time)
    {GenServer.call(:graphrepo, {:update_edges, pairs, target, graph}), pairs}
  end

  def get_edge_hop_pairs(graph, id, time) do
    neighbors = graph.edges |> Map.get(id) |> MapSet.to_list
    predictions = Enum.flat_map(neighbors, fn(x) -> [x[:to]] end) |> Droneportrepo.get_predictions_for(Timex.to_unix(time))
    get_pairs(neighbors, neighbors, predictions) |> filter_for_best_option
  end

  defp get_pairs([], _n, _predictions), do: %{}
  defp get_pairs([h | t], n, predictions) do
    Map.merge(get_pairs(t, n, predictions), %{h[:to] => match(n, h, predictions)})
  end

  defp match([], _to, _predictions), do: []
  defp match([h | t], to, predictions) do
    # TODO consider a different approach for cost calculation where costs do not skyrocket (see pictre in WhatsApp)
    takefac = Droneportrepo.get_predicted_cost_factor(predictions, h[:to], :take)
    givefac = Droneportrepo.get_predicted_cost_factor(predictions, to[:to], :give)
    match(t, to, predictions) ++ [%{from: h[:to], costs: h[:costs] * takefac + to[:costs] * givefac}]
  end

  defp filter_for_best_option(pairs) do
    do_filter(Map.keys(pairs), pairs)
  end
  defp do_filter([], _pairs), do: %{}
  defp do_filter([key | t], pairs) do
    best = Map.get(pairs, key) |> Enum.min_by(fn(x) -> x[:costs] end)
    Map.merge(do_filter(t, pairs), %{key => best})
  end

  def add_edge_hops(route, edge_hops, :start), do: [edge_hops[Enum.at(route, 1)][:from]] ++ route
  def add_edge_hops(route, edge_hops, :end), do: route ++ [edge_hops[Enum.at(route, 1)][:from]]

  # TODO format time to ISO:Extended for database: Timex.shift(Timex.from_unix(1517571316145, :milliseconds), [hours: 1])
  # Looks like this in the end:
  # %{is_delivery: true/false, route: [%{from: "id", to: "id"}]}
  defp build_map(route, delivery) do
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

