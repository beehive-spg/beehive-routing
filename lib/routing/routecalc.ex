defmodule Routing.Routecalc do
  require Logger
  use Timex

  alias Routing.Graphrepo
  alias Routing.Routerepo

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
            ideal = Graph.shortest_path(graph, :"dp#{start_building}", :"dp#{target_building}")
            build_map(ideal, delivery) |> Routerepo.get_real_data
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

