defmodule Routing.Graphrepo do
  require Logger
  use GenServer

  @url Application.fetch_env!(:routing, :database_url)

  def handle_call({:get_graph_delivery, start, target}, _from, _state) do
    start = String.to_integer(start)
    target = String.to_integer(target)

    Logger.debug("Fetching graph for shop: #{start} to customer: #{target}")

    start_building = get_building_for(start, :shops)
    target_building = get_building_for(target, :customers)
    graph = build_graph(start_building, target_building)

    {:reply, {graph, start_building["db/id"], target_building["db/id"]}, graph}
  end
  
  def handle_call({:get_graph_distribution, start, target}, _from, _state) do
    start = String.to_integer(start)
    target = String.to_integer(target)

    Logger.debug("Fetching graph for distribution building from: #{start} to building to: #{target}")

    start_building = get_building_for(start, :buildings)
    target_building = get_building_for(target, :buildings)
    graph = build_graph(start_building, target_building)

    {:reply, {graph, start_building["db/id"], target_building["db/id"]}, graph}
  end

  def handle_call({:update_edges, toupdate, target, graph}, _from, _state) do
    graph = do_update(graph, target, Map.keys(toupdate), toupdate)
    {:reply, graph, graph}
  end

  defp build_graph(from, to) do
    hives = get_hives()
    edges = get_edges(from["db/id"], to["db/id"]) #NOTE workaraound because it only works with building ids for now
    transform_to_graph(hives, edges, from, to)
  end

  defp get_building_for(id, table) do
    case table do
      :buildings ->
        # TODO change to hives because only hives are requested here
        result = case HTTPotion.get(@url <> "/one/buildings/#{id}") do
          %{:body => b, :headers => _, :status_code => 200} ->
            Logger.debug("Fetching building succeeded with code 200")
            Poison.decode!(~s/#{b}/)
          %{:body => b, :headers => _, :status_code => s} ->
            Logger.error("Fetching building returned a bad status code: #{s} with error message #{b}")
        end
      :shops ->
        shops = case HTTPotion.get(@url <> "/shops") do
          %{:body => b, :headers => _, :status_code => 200} ->
            Logger.debug("Fetching shops succeeded with code 200")
            Poison.decode!(~s/#{b}/)
          %{:body => b, :headers => _, :status_code => s} ->
            Logger.error("Fetching shops returned a bad status code: #{s} with error message #{b}")
        end
        do_find_entitiy(shops, id, :shop)
      :customers ->
        customers = case HTTPotion.get(@url <> "/customers") do
          %{:body => b, :headers => _, :status_code => 200} ->
            Logger.debug("Fetching customers succeeded with code 200")
            Poison.decode!(~s/#{b}/)
          %{:body => b, :headers => _, :status_code => s} ->
            Logger.error("Fetching customers returned a bad status code: #{s} with error message #{b}")
        end
        do_find_entitiy(customers, id, :customer)
    end
  end

  defp do_find_entitiy([], entity, description), do: Logger.error("Could not find entity for id #{entity} and description #{description}")
  defp do_find_entitiy([h | t], entity, description) do
    result = Map.get(h, "building/#{description}") |> Enum.at(0) |> Map.get("db/id")
    case result do
      ^entity ->
        h
      _ -> 
        do_find_entitiy(t, entity, description)
    end
  end

  defp get_hives do
    # TODO implement to include Shop and Customer
    case HTTPotion.get("#{Application.fetch_env!(:routing, :database_url)}/hives") do
      %{:body => b, :headers => _, :status_code => 200} ->
        Logger.debug("Fetching hives succeded with code 200")
        Poison.decode!(~s/#{b}/)
      %{:body => b, :headers => _, :status_code => s} ->
        Logger.error("Fetching hives returned a bad status code: #{s} with error message #{b}")
    end
  end

  defp get_edges(from, to) do
    case HTTPotion.get("#{Application.fetch_env!(:routing, :database_url)}/api/reachable?customerid=#{to}&shopid=#{from}") do
      %{:body => b, :headers => _, :status_code => 200} ->
        Logger.debug("Fetching connections for #{from} and #{to} succeded with code 200")
        Poison.decode!(~s/#{b}/)
      %{:body => b, :headers => _, :status_code => s} ->
        Logger.error("Database returned a bad status code upon fetching connections: #{s} with message #{b}")
    end
  end

  defp transform_to_graph(hives, edges, from, to) do
    # TODO maybe work with the state of the server instead of creating a new graph
    # (depends on graph brewer if it is able to update an existing graph)
    graph = add_nodes(hives, from, to)
    graph = add_edges(edges, graph)
    graph = filter_errors(graph)
    graph
  end

  # TODO nil is a workaround to enable first inserting of shop and cust
  defp add_nodes(hives, from, to) do
    graph = Graph.add_node(Graph.new, :"dp#{Map.get(to, "db/id")}", %{costs: 0, label: "Target"})
            |> Graph.add_node(:"dp#{Map.get(from, "db/id")}", %{costs: get_heur_costs_buildings(from, to), label: "Start"})
    add_nodes(hives, from, to, graph)
  end
  defp add_nodes([], _, _, graph), do: graph
  defp add_nodes([building | t], from, to, graph) do
    # TODO enable for customer and shops because they are not a hive
    hive = Map.get(building, "building/hive")
    Graph.add_node(add_nodes(t, from, to, graph), 
                    :"dp#{Map.get(building, "db/id")}",
                    %{costs: get_heur_costs_buildings(building, to), label: Map.get(hive, "hive/name")})
  end

  defp add_edges([], graph), do: graph
  defp add_edges([edge | t], graph) do
    from = :"dp#{Map.get(Map.get(edge, "connection/start"), "db/id")}"
    to = :"dp#{Map.get(Map.get(edge, "connection/end"), "db/id")}"
    costs = round(Map.get(edge, "connection/distance"))
    graph = Graph.add_edge(add_edges(t, graph), from, to, costs)
    graph
  end

  defp filter_errors(graph) do
    Map.keys(graph.nodes) |> do_filter_errors(graph)
  end
  defp do_filter_errors([], graph), do: graph
  defp do_filter_errors([h | t], graph) do
    case Graph.get_node(graph, h) do
      %{costs: 0, label: nil} ->
        do_filter_errors(t, Graph.delete_node(graph, h))
      _ ->
        do_filter_errors(t, graph)
    end
  end

  defp get_heur_costs_buildings(from, to) do
    round(Distance.GreatCircle.distance(
      {Map.get(from, "building/xcoord"), Map.get(from, "building/ycoord")},
      {Map.get(to, "building/xcoord"), Map.get(to, "building/ycoord")}
    ))
  end

  defp do_update(graph, _target, [], _data), do: graph
  defp do_update(graph, target, [from | t], data) do
    do_update(graph, target, t, data) |> Graph.add_edge(from, target, data[from][:costs])
  end
end

