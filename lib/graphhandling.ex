defmodule Routing.Graphhandling do
  use GenServer
  #use Graph

  @link "http://linktorestapi.com"

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, Graph.new(type: :undirected))
  end

  def get_graph do
    update
  end

  defp update do
    # TODO fetch from db
    state = Graph.new(type: :undirected)
            |> Graph.add_vertices([:dp1, :dp2, :dp3, :dp4, :dp5, :dp6, :dp7, :dp8, :dp9, :dp10])
            |> Graph.add_edges([{:dp1, :dp2, [label: 5]}, {:dp2, :dp3, [label: 5]}, {:dp3, :dp4, [label: 5]}])
            |> Graph.add_edges([{:dp4, :dp5, [label: 5]}, {:dp4, :dp5, [label: 5]}, {:dp5, :dp6, [label: 5]}])
            |> Graph.add_edges([{:dp6, :dp7, [label: 5]}, {:dp7, :dp8, [label: 5]}, {:dp8, :dp9, [label: 5]}])
            |> Graph.add_edges([{:dp9, :dp10, [label: 5]}, {:dp3, :dp5, [label: 5]}, {:dp5, :dp1, [label: 5]}])
            |> Graph.add_edges([{:dp6, :dp3, [label: 5]}])
    {:ok, state}
  end

end
