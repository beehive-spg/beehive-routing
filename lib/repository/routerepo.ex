defmodule Routing.Routerepo do
  require Logger

  # NOTE upon receiving an error on some routes a retry is initiated.
  # This is necessary to work around a knwon bug that occurs when
  # the database has been running for a longer time.
  # It is not yet known why the bug appears, but this fixes it.
  # In case of endless warning messages, restart the application or
  # terminate the process.

  @url Application.fetch_env!(:routing, :database_url)

  def insert_route(route) do
    data = transform_to_db_format(route) |> Poison.encode!
    case HTTPotion.post(@url <> "/routes", [body: data, headers: ["Content-Type": "application/json"]]) do
      %{:body => b, :headers => _, :status_code => 201} ->	
        Logger.debug("Route inserted successfully")
        # Transforms to fromat that can instantly be inserted into the redis db
        redis = Poison.decode!(~s/#{b}/) |> transform_to_redis_format
      %{:body => b, :headers => _, :status_code => s} ->
        Logger.warn("Error #{s} occured trying to insert route #{data} on url #{@url} with error message #{b}. Now retrying ...")
        insert_route(route)
    end
  end

  def insert_order(shop, customer, routeid, generated) do
    data = %{
      "shopid"      => shop |> String.to_integer,
      "customerid"  => customer |> String.to_integer,
      "route"       => routeid |> String.to_integer,
      "source"      => (if generated, do: "order.source/generated", else: "order.source/gui")
    } |> Poison.encode!
    result = case HTTPotion.post(@url <> "/orders", [body: data, headers: ["Content-Type": "application/json"]]) do
      %{:body => b, :headers => _, :status_code => 201} ->	
        Logger.debug("Inserting order succeeded with code 200")
        Poison.decode!(~s/#{b}/)
      %{:body => b, :headers => _, :status_code => s} ->
        Logger.warn("Error #{s} occured trying to insert order #{data} on url #{@url} with error message #{b}. Now retrying ...")
        insert_order(shop, customer, routeid, generated)
    end
    result
  end

  def is_reachable(building1, building2) do
    result = case HTTPotion.get(@url <> "/api/reachable/#{building1}/#{building2}") do
      %{:body => b, :headers => _, :status_code => 200} ->	
        Logger.debug("Is reachable from #{building1} to #{building2} succeeded with code 200")
        Poison.decode!(~s/#{b}/)
      %{:body => b, :headers => _, :status_code => s} ->
        Logger.warn("Error #{s} occured trying to check reachable for #{building1} and #{building2} on url #{@url} with error code #{s} and message #{b}")
    end
    result
  end

  def try_route(route, format \\ false) do
    data = transform_to_db_format(route) |> Poison.encode!
    result = case HTTPotion.post(@url <> "/api/tryroute", [body: data, headers: ["Content-Type": "application/json"]]) do
      %{:body => b, :headers => _, :status_code => 200} ->	
        Logger.debug("Route inserted successfully")
        # Transforms to fromat that can instantly be inserted into the redis db
        map = Poison.decode!(~s/#{b}/)
        if format do
          map = transform_to_redis_format(map)
        end
        map
      %{:body => b, :headers => _, :status_code => s} ->
        Logger.warn("Error #{s} occured trying to fetch predicted route information for #{data} on url #{@url} with error message #{b}. Now retrying ...")
        try_route(route)
    end
    result
  end

  def notify_departure(hop) do
    data = Poison.encode!(hop)
    case HTTPotion.post(@url <> "/api/departure", [body: data, headers: ["Content-Type": "application/json"]]) do
      %{:body => b, :headers => _, :status_code => 204} ->	
        Logger.debug("Notifying about departure succeeded")
      %{:body => b, :headers => _, :status_code => s} ->
        Logger.warn("Error #{s} occured trying to notify departure information for #{data} on url #{@url} with error message #{b}")
    end
  end

  def notify_arrival(hop) do
    data = Poison.encode!(hop)
    case HTTPotion.post(@url <> "/api/arrival", [body: data, headers: ["Content-Type": "application/json"]]) do
      %{:body => b, :headers => _, :status_code => 204} ->	
        Logger.debug("Notifying about arrival succeeded")
      %{:body => b, :headers => _, :status_code => s} ->
        Logger.warn("Error #{s} occured trying to notify arrival information for #{data} on url #{@url} with error message #{b}")
    end
  end

  defp transform_to_db_format(%{route: hops, time: time, is_delivery: delivery}) do
    case delivery do
      true ->
        %{hops: hops, time: Timex.to_unix(time)*1000, origin: "route.origin/order"}
      false ->
        %{hops: hops, time: Timex.to_unix(time)*1000, origin: "route.origin/distribution"}
    end
  end

  defp transform_to_redis_format(route), do: transform_hops(route["hop/_route"], route["db/id"])

  defp transform_hops([], _route_id), do: []
  defp transform_hops([h | t], route_id) do
    hop = %{dep_time: "#{Timex.from_unix(round(h["hop/starttime"]/1000))}",
      arr_time: "#{Timex.from_unix(round(h["hop/endtime"]/1000))}",
      hop: "#{h["db/id"]}",
      route_id: "#{route_id}"}
    [hop] ++ transform_hops(t, route_id)
  end
end

