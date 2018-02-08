defmodule Routing.Routerepo do
  require Logger

  def get_real_data(route) do
    data = Poison.encode!(route)
    route
  end

  def insert_route(route) do
    data = transform_to_db_format(route) |> Poison.encode!
    # result = case HTTPotion.get(Application.fetch_env!(:routing, :database_url) <> "/routes", [body: data]) do 
        # %{:body => b, :headers => _, :status_code => 200} ->
          # Logger.debug("Route inserted successfully")
          # Poison.decode!(~s/#{b}/)
        # %{:body => _, :headers => _, :status_code => s} ->
          # Logger.error("Error #{s} occured trying to insert route #{data}")
      # end
      # NOTE Workaround because HTTPotion is not able to handle redirects correctly
    response = HTTPotion.post(Application.fetch_env!(:routing, :database_url) <> "/routes",
                                                  [body: data])
    result = case HTTPotion.get(Application.fetch_env!(:routing, :database_url) <> response.headers.hdrs["location"]) do
      %{:body => b, :headers => _, :status_code => 200} ->	
        Logger.debug("Route inserted successfully")
        # Transforms to fromat that can instantly be inserted into the redis db
        Poison.decode!(~s/#{b}/) |> transform_to_routing_format
      %{:body => _, :headers => _, :status_code => s} ->
        Logger.error("Error #{s} occured trying to insert route #{data}")
    end
    result
  end
  defp transform_to_db_format(route) do
    %{route: hops, time: time, is_delivery: delivery} = route
    result = case delivery do
      true ->
        %{hops: hops, time: Timex.to_unix(time)*1000, origin: ":origin/ORDER"}
      false ->
        %{hops: hops, time: Timex.to_unix(time)*1000, origin: ":origin/DISTRIBUTION"}
    end
    result
  end
  defp transform_to_routing_format(route) do
    transform_hops(route["_route"], route["id"])
  end
  defp transform_hops([], route_id), do: []
  defp transform_hops([h | t], route_id) do
    hop = %{dep_time: "#{Timex.from_unix(round(h["starttime"]/1000))}",
      arr_time: "#{Timex.from_unix(round(h["endtime"]/1000))}",
      hop: "#{h["id"]}",
      route_id: "#{route_id}"}
    [hop] ++ transform_hops(t, route_id)
  end
end

