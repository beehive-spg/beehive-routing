defmodule Routing.Routecalc do
  require Logger

  def setup do
    {:ok, pid} = GenServer.start_link(Routing.Graphhandling, Graph.new, name: :graphhandling)
    Logger.info "Graphhandler started."
    :ok
  end

  def calc(data) do
    graph = GenServer.call(:graphhandling, {:get_for, data})
    ideal = Graph.shortest_path(graph, :"dp#{data["from"]}", :"dp#{data["to"]}") # TODO currently prefixing dp (because there are only dp in the graph) needs to be adapted when real data is tested
    ideal
  end

end
