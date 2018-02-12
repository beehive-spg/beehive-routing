defmodule Routing.Routerepo do
  require Logger

  def get_real_data(route) do
    data = Poison.encode!(route)
    route
  end

  def insert_route(route) do
    data = transform_to_db_format(route) |> Poison.encode!
    result = case HTTPotion.post(Application.fetch_env!(:routing, :database_url) <> "/routes",
                                                        [body: data, headers: ["Content-Type": "application/json"]]) do
      %{:body => b, :headers => _, :status_code => 201} ->	
        Logger.debug("Route inserted successfully")
        # Transforms to fromat that can instantly be inserted into the redis db
        Poison.decode!(~s/#{b}/) |> transform_to_redis_format
      %{:body => b, :headers => _, :status_code => s} ->
        Logger.error("Error #{s} occured trying to insert route #{data} on url #{Application.fetch_env!(:routing, :database_url)} with error message #{b}")
    end
    result
  end
  def transform_to_db_format(route) do
    %{route: hops, time: time, is_delivery: delivery} = route
    result = case delivery do
      true ->
        %{hops: hops, time: Timex.to_unix(time)*1000, origin: "route.origin/order"}
      false ->
        %{hops: hops, time: Timex.to_unix(time)*1000, origin: "route.origin/distribution"}
    end
    result
  end
  def transform_to_redis_format(route), do: transform_hops(route["hop/_route"], route["db/id"])
  def transform_hops([], _route_id), do: []
  def transform_hops([h | t], route_id) do
    hop = %{dep_time: "#{Timex.from_unix(round(h["hop/starttime"]/1000))}",
      arr_time: "#{Timex.from_unix(round(h["hop/endtime"]/1000))}",
      hop: "#{h["db/id"]}",
      route_id: "#{route_id}"}
    [hop] ++ transform_hops(t, route_id)
  end
end

