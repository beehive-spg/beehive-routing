defmodule Routing.Routecalc do
  require Logger
  use Timex

  def setup do
    {:ok, pid} = GenServer.start_link(Routing.Graphhandling, Graph.new, name: :graphhandling)
    Logger.info("Graphhandler started.")
  end
  # TODO add parameter for if delivery
  def calc(data) do
    case GenServer.whereis(:graphhandling) do
      nil ->
        setup
        calc(data)
      _ ->
        graph = GenServer.call(:graphhandling, {:get_for, data})
        ideal = Graph.shortest_path(graph, :"dp#{data["from"]}", :"dp#{data["to"]}")
        # TODO currently prefixing dp (because there are only dp in the graph) needs to be adapted when real data is tested
        data = build_buffer_data(graph, ideal)
        notify_buffer(data)
        ideal
    end
  end
  def notify_buffer(info) do
    Routing.Redixcontrol.add_route(info)
  end
  # NOTE this method excludes atoms that have no numbers
  # TODO number is currently just a help to identify how many 10sec to shift the time for the next event
  def build_buffer_data(graph, route) do
    %{is_delivery: false, route: transform_to_buffer_map(graph, route, Timex.shift(Timex.now, [hours: 1, seconds: 1]))}
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
  defp transform_to_buffer_map(g, [from | [to | tail] = next], t) do
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

