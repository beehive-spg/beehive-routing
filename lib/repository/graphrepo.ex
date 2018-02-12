defmodule Routing.Graphrepo do
  require Logger
  use GenServer

  def handle_call({:get_graph_for, from, to}, _from, _state) do
    Logger.debug("Fetching graph for #{from}, #{to}")
    hives = get_hives(from, to)
    edges = get_edges(from, to)
    s = get_start(hives, String.to_integer(from))
    t = get_target(hives, String.to_integer(to))
    graph = transform_to_graph(hives, edges, s, t)
    {:reply, graph, graph}
  end
  defp get_hives(_shop, _cust) do
    # TODO implement to include Shop and Customer
    case HTTPotion.get("#{Application.fetch_env!(:routing, :database_url)}/hives") do
      %{:body => b, :headers => _, :status_code => 200} ->
        Logger.debug("Fetching hives succeded with code 200")
        Poison.decode!(~s/#{b}/)
      %{:body => b, :headers => _, :status_code => s} ->
        Logger.error("Fetching hives returned a bad status code: #{s} with error message #{b}")
    end
  end
  defp get_edges(_shop, _cust) do
    # TODO implement to include Shop and Customer
    case HTTPotion.get("#{Application.fetch_env!(:routing, :database_url)}/api/reachable") do
      %{:body => b, :headers => _, :status_code => 200} ->
        Logger.debug("Fetching hives succeded with code 200")
        Poison.decode!(~s/#{b}/)
      %{:body => _, :headers => _, :status_code => s} ->
        Logger.error("Database returned a bad status code: #{s}")
    end
  end
  # TODO can be made more dry
  defp get_start([], from), do: Logger.error("Start not found in fetched graph #{from}")
  defp get_start([building | t], from) do
    case Map.get(building, "db/id") do
      ^from ->
        building
      _ ->
        get_start(t, from)
    end
  end
  defp get_target([], to), do: Logger.error("Destination not found in fetched graph: #{to}")
  defp get_target([building | t], to) do
    case Map.get(building, "db/id") do
      ^to ->
        building
      _ ->
        get_target(t, to)
    end
  end
  defp transform_to_graph(hives, edges, from, to) do
    # TODO maybe work with the state of the server instead of creating a new graph
    # (depends on graph brewer if it is able to update an existing graph)
    graph = add_nodes(hives, from, to, Graph.new)
    graph = add_edges(edges, graph)
    graph
  end
  defp add_nodes([], _from, _to, graph), do: graph
  defp add_nodes([building | t], from, to, graph) do
    # TODO enable for customer and shops because they are not a hive
    heur_costs = round(Distance.GreatCircle.distance(
      {Map.get(building, "building/xcoord"), Map.get(building, "building/ycoord")},
      {Map.get(to, "building/xcoord"), Map.get(to, "building/ycoord")}
    ))
    hive = Map.get(building, "building/hive")
    graph = Graph.add_node(add_nodes(t, from, to, graph),
                            :"dp#{Map.get(building, "db/id")}",
                            %{costs: heur_costs, label: Map.get(hive, "hive/name")})
    graph
  end
  defp add_edges([], graph), do: graph
  defp add_edges([edge | t], graph) do
    from = :"dp#{Map.get(Map.get(edge, "connection/start"), "db/id")}"
    to = :"dp#{Map.get(Map.get(edge, "connection/end"), "db/id")}"
    costs = round(Map.get(edge, "connection/distance"))
    graph = Graph.add_edge(add_edges(t, graph), from, to, costs)
    graph
  end

end
