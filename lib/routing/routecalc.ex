defmodule Routing.Routecalc do
  require Logger
  use Timex

  alias Routing.Graphrepo
  alias Routing.Routerepo
  alias Routing.Redixcontrol

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
        graph = GenServer.call(:graphrepo, {:get_graph_for, Map.get(data, "from"), Map.get(data, "to")})
        ideal = Graph.shortest_path(graph, :"dp#{Map.get(data, "from")}", :"dp#{Map.get(data, "to")}")
        # TODO currently prefixing dp (because there are only dp in the graph) needs to be adapted when real data is tested
        # data = build_buffer_data(graph, ideal, delivery)
        data = build_map(ideal, delivery)
        data = Routerepo.get_real_data(data) # Update the costs for the ideal route to the predicted costs
        # TODO route evaluation when Emin implements post get redirect for adding posts
        # Redixcontrol.add_route(info)
        Routerepo.insert_route(data)
        data
    end
  end

  # TODO format time to ISO:Extended for database: Timex.shift(Timex.from_unix(1517571316145, :milliseconds), [hours: 1])
  # Looks like this in the end:
  # %{is_delivery: true/false, route: [%{from: "id", to: "id"}]}
  def build_map(route, delivery) do
    start_time = Timex.shift(Timex.now, [hours: 1, seconds: 5]) # Five seconds delay for a route to be flown
    %{is_delivery: delivery, time: start_time, route: do_build_map(route)}
  end
  defp do_build_map([from | []]), do: []
  defp do_build_map([from | [to | _] = next]) do
    from = Regex.replace(~r/[A-Za-z]*/, "#{from}", "")
    to   = Regex.replace(~r/[A-Za-z]*/, "#{to}", "")
    [%{from: from, to: to}] ++ do_build_map(next)
  end

  ####### OLD #######
  # NOTE this method excludes atoms that have no numbers
  def build_buffer_data(graph, route, delivery) do
    %{is_delivery: delivery, route: transform_to_buffer_map(graph, route, Timex.shift(Timex.now, [hours: 1, seconds: 1]))}
    #%{is_delivery: false, route: transform_to_buffer_map(graph, route, Timex.shift(Timex.now, [hours: 1, seconds: 3]))}
  end
  defp transform_to_buffer_map(g, [from | [to | []]], t) do
    ffrom = Regex.replace(~r/[A-Za-z]*/, Atom.to_string(from), "")
    fto   = Regex.replace(~r/[A-Za-z]*/, Atom.to_string(to), "")
    dtime = Timex.shift(t, [seconds: 0])
    #dtime = Timex.shift(t, [seconds: 3])
    {seconds, mill} = get_duration(g, from, to)
    atime = Timex.shift(dtime, [seconds: seconds, milliseconds: mill])
    [%{from: ffrom, to: fto, dep_time: "#{dtime}", arr_time: "#{atime}", drone: droneid()}]
  end
  defp transform_to_buffer_map(g, [from | [to | _] = next], t) do
    ffrom = Regex.replace(~r/[A-Za-z]*/, Atom.to_string(from), "")
    fto   = Regex.replace(~r/[A-Za-z]*/, Atom.to_string(to), "")
    dtime = Timex.shift(t, [seconds: 0])
    #dtime = Timex.shift(t, [seconds: 3])
    {seconds, mill} = get_duration(g, from, to)
    atime = Timex.shift(dtime, [seconds: seconds, milliseconds: mill])
    [%{from: ffrom, to: fto, dep_time: "#{dtime}", arr_time: "#{atime}", drone: droneid()}] ++ transform_to_buffer_map(g, next, atime)
  end
  # NOTE used because Emin is not ready yet
  defp droneid() do
    time = Timex.to_gregorian_microseconds(Timex.now)
    time - (round(Float.floor(time / 100_000_000)) * 100_000_000)
  end
  defp get_duration(g, from, to) do
    dur = Graph.hop_costs(g, from, to)
    IO.puts "#{from} - #{to} :: #{dur}"
    {round(Float.floor(dur / 10)), rem(dur, 10) * 100}
  end
end

