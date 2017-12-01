defmodule Routing.Graphhandling do
  use GenServer

  #@link "http://linktorestapi.com"

  def get_graph_for(server, %{"from" => from, "to" => to} = destinations) when is_atom(from) and is_atom(to) do
    GenServer.call(server, {:get_for, destinations}) # TODO throw error if location not available
  end

  def handle_call({:get_for, destination}, _from, state) do
    {:ok, new} = update()
    # TODO fetch from db
    # TODO the locations (shop and customer) need to be added when calling this method. Disabled currently because we only test dp to dp atm
    # TODO return the current state if the database (emin) says that nothing has changes
    # graph = Graph.add_edge(new, [{:shop, :dp2, 5}, {:shop, :dp10, 7}, {:cust, :dp7, 2}])
    # graph = new
    #  |> Graph.add_edge(:shop, :dp2, 5)
    #  |> Graph.add_edge(:shop, :dp10, 7)
    #  |> Graph.add_edge(:cust, :dp7, 2)
    # {:reply, graph, new}
    {:reply, new, new}
  end

  defp update do
    # TODO fetch from db
    #state = Graph.new(type: :undirected)
    #        |> Graph.add_edges([{:dp1, :dp2, [weight: 3]}, {:dp2, :dp3, [weight: 6]}, {:dp3, :dp4, [weight: 5]}])
    #        |> Graph.add_edges([{:dp4, :dp5, [weight: 4]}, {:dp4, :dp6, [weight: 5]}, {:dp5, :dp6, [weight: 6]}])
    #        |> Graph.add_edges([{:dp6, :dp7, [weight: 5]}, {:dp7, :dp8, [weight: 4]}, {:dp8, :dp9, [weight: 2]}])
    #        |> Graph.add_edges([{:dp9, :dp10, [weight: 6]}, {:dp3, :dp5, [weight: 3]}, {:dp5, :dp1, [weight: 7]}])
    #        |> Graph.add_edges([{:dp6, :dp3, [weight: 7]}])
    state = Graph.new
      |> Graph.add_node(:dp0, %{costs: 0, label: "Spengergasse"})
      |> Graph.add_node(:dp1, %{costs: 0, label: "Hofburg"})
      |> Graph.add_node(:dp2, %{costs: 0, label: "Stephansplatz"})
      |> Graph.add_node(:dp3, %{costs: 0, label: "Flex Cafe"})
      |> Graph.add_node(:dp4, %{costs: 0, label: "Hard Rock Cafe"})
      |> Graph.add_node(:dp5, %{costs: 0, label: "MAK"})
      |> Graph.add_node(:dp6, %{costs: 0, label: "Karlsplatz"})
      |> Graph.add_node(:dp7, %{costs: 0, label: "Cineplex Apollo Kino"})
      |> Graph.add_node(:dp8, %{costs: 0, label: "Krankenhaus"})
      |> Graph.add_node(:dp9, %{costs: 0, label: "Westbahnhof"})
      |> Graph.add_node(:dp10, %{costs: 0, label: "Stadthalle"})
      |> Graph.add_node(:dp11, %{costs: 0, label: "Rathaus"})
      |> Graph.add_node(:dp12, %{costs: 0, label: "Votivkirche"})
      |> Graph.add_node(:dp13, %{costs: 0, label: "AKH"})
      |> Graph.add_node(:dp14, %{costs: 0, label: "Uni Campus"})
      |> Graph.add_node(:dp15, %{costs: 0, label: "Bruno Bettelheim Haus"})
      |> Graph.add_node(:dp16, %{costs: 0, label: "Museum"})
      |> Graph.add_node(:dp17, %{costs: 0, label: "Schäffergasse"})
      |> Graph.add_node(:dp18, %{costs: 0, label: "Matzleinsdorferplatz"})
      |> Graph.add_node(:dp19, %{costs: 0, label: "Hauptbahnhof"})
      |> Graph.add_node(:dp20, %{costs: 0, label: "Belvedere"})
      |> Graph.add_node(:dp21, %{costs: 0, label: "Universität Musik/Kunst"})
      |> Graph.add_node(:dp22, %{costs: 0, label: "Hundertwasserhaus"})

    state = state
      |> Graph.add_edge(:dp0, :dp18,0)
      |> Graph.add_edge(:dp0, :dp19,0)
      |> Graph.add_edge(:dp0, :dp17,0)
      |> Graph.add_edge(:dp0, :dp8, 0)
      |> Graph.add_edge(:dp0, :dp7, 0)

    state = state
      |> Graph.add_edge(:dp1, :dp6, 0)
      |> Graph.add_edge(:dp1, :dp11,0)
      |> Graph.add_edge(:dp1, :dp12,0)
      |> Graph.add_edge(:dp1, :dp2, 0)
      |> Graph.add_edge(:dp1, :dp16,0)
      |> Graph.add_edge(:dp1, :dp3, 0)
      |> Graph.add_edge(:dp1, :dp4, 0)

    state = state
      |> Graph.add_edge(:dp2, :dp11,0)
      |> Graph.add_edge(:dp2, :dp12,0)
      |> Graph.add_edge(:dp2, :dp3, 0)
      |> Graph.add_edge(:dp2, :dp5, 0)
      |> Graph.add_edge(:dp2, :dp6, 0)
      |> Graph.add_edge(:dp2, :dp4, 0)

    state = state
      |> Graph.add_edge(:dp3, :dp12,0)
      |> Graph.add_edge(:dp3, :dp11,0)
      |> Graph.add_edge(:dp3, :dp4, 0)

    state = state
      |> Graph.add_edge(:dp4, :dp5, 0)
      |> Graph.add_edge(:dp4, :dp22,0)

    state = state
      |> Graph.add_edge(:dp5, :dp22,0)
      |> Graph.add_edge(:dp5, :dp6, 0)
      |> Graph.add_edge(:dp5, :dp21,0)

    state = state
      |> Graph.add_edge(:dp6, :dp20,0)
      |> Graph.add_edge(:dp6, :dp17,0)
      |> Graph.add_edge(:dp6, :dp21,0)

    state = state
      |> Graph.add_edge(:dp7, :dp16,0)
      |> Graph.add_edge(:dp7, :dp9, 0)
      |> Graph.add_edge(:dp7, :dp8, 0)
      |> Graph.add_edge(:dp7, :dp17,0)
      |> Graph.add_edge(:dp7, :dp15,0)

    state = state
      |> Graph.add_edge(:dp8, :dp9, 0)
      |> Graph.add_edge(:dp8, :dp17,0)
      |> Graph.add_edge(:dp8, :dp16,0)

    state = state
      |> Graph.add_edge(:dp9, :dp16,0)
      |> Graph.add_edge(:dp9, :dp10,0)

    state = state
      |> Graph.add_edge(:dp10, :dp16,0)
      |> Graph.add_edge(:dp10, :dp15,0)

    state = state
      |> Graph.add_edge(:dp11, :dp12,0)
      |> Graph.add_edge(:dp11, :dp15,0)
      |> Graph.add_edge(:dp11, :dp13,0)

    state = state
      |> Graph.add_edge(:dp12, :dp15,0)
      |> Graph.add_edge(:dp12, :dp13,0)
      |> Graph.add_edge(:dp12, :dp14,0)

    state = state
      |> Graph.add_edge(:dp13, :dp14,0)

    state = state
      |> Graph.add_edge(:dp15, :dp16,0)

    state = state
      |> Graph.add_edge(:dp17, :dp20,0)

    state = state
      |> Graph.add_edge(:dp18, :dp19,0)

    state = state
      |> Graph.add_edge(:dp19, :dp20,0)

    state = state
      |> Graph.add_edge(:dp20, :dp21,0)

    state = state
      |> Graph.add_edge(:dp21, :dp22,0)

    {:ok, state}
  end
end

