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
        notify_buffer(ideal)
        ideal
    end
  end
  def notify_buffer(route) do
    info = %{is_delivery: false, route: transform_to_buffer_map(route, 1)}
    Routing.Redixcontrol.add_route(info)
  end
  # NOTE this method excludes atoms that have no numbers
  # TODO number is currently just a help to identify how many 10sec to shift the time for the next event
  def transform_to_buffer_map([from | [to | []]], t) do
    ffrom = Regex.replace(~r/[A-Za-z]*/, Atom.to_string(from), "")
    fto   = Regex.replace(~r/[A-Za-z]*/, Atom.to_string(to), "")
    dtime = Timex.shift(Timex.now, [hours: 1, seconds: 10*t+5])
    atime = Timex.shift(Timex.now, [hours: 1, seconds: 10*(t+2)])
    [%{from: ffrom, to: fto, dep_time: "#{dtime}", arr_time: "#{atime}", drone: droneid()}]
  end
  def transform_to_buffer_map([from | [to | tail] = next], t) do
    ffrom = Regex.replace(~r/[A-Za-z]*/, Atom.to_string(from), "")
    fto   = Regex.replace(~r/[A-Za-z]*/, Atom.to_string(to), "")
    dtime = Timex.shift(Timex.now, [hours: 1, seconds: 10*t+5])
    atime = Timex.shift(Timex.now, [hours: 1, seconds: 10*(t+2)])
    [%{from: ffrom, to: fto, dep_time: "#{dtime}", arr_time: "#{atime}", drone: droneid()}] ++ transform_to_buffer_map(next, t+2)
  end
  def droneid() do
    time = Timex.to_gregorian_microseconds(Timex.now)
    time - round(time / 100_000_000) * 100_000_000
  end
end

