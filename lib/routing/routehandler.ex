defmodule Routing.Routehandler do
  require Logger

  alias Routing.Routecalc
  alias Routing.Routerepo
  alias Routing.Redixcontrol

  def calc_delivery(payload) do
    {status, data} = process_message(payload)
    cond do
      status == :err ->
        {:err, data}
      !verify_data(data) ->
        {:err, "Invalid data for delivery found: #{data}"}
      true ->
        Logger.info("Order for: ID: #{data["id"]}: #{data["from"]}, #{data["to"]}")
        route = calc_route(data, :delivery) |> Routerepo.insert_route
        routeid = Enum.at(route, 0)[:route_id]
        Routerepo.insert_order(data["from"], data["to"], routeid, false)
        Redixcontrol.add_route(route)
        {:ok, "Delivery with route id #{routeid} successfully calculated"}
    end
  end

  def calc_distribution(payload) do
    {status, data} = process_message(payload)
    cond do
      status == :err ->
        {:err, "Invalid data for distribution found: #{data}"}
      !verify_data(data) ->
        {:err, "Invalid data in data found: #{data}"}
      true ->
        Logger.info("Distribution for: ID: #{data["id"]}: #{data["from"]}, #{data["to"]}")
        route = calc_route(data, :distribution) |> Routerepo.insert_route
        Redixcontrol.add_route(route)
        routeid = Enum.at(route, 0)[:route_id]
        {:ok, "Distribution with routeid #{routeid} successfully calculated"}
    end
  end

  defp calc_route(data, delivery), do: Routecalc.calc(data, delivery)

  defp verify_data(data) do
    # TODO implement
    true
  end

  defp process_message(payload) do
    order = Poison.decode!(~s(#{payload}))
    {:ok, order}
  rescue
    Protocol.UndefinedError ->
      {:err, "JSON for new order could not be processed. Data: #{payload}"}
    Poison.SyntaxError ->
      {:err, "JSON for new order could not be processed. Data: #{payload}"}
  end
end

