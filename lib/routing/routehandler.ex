defmodule Routing.Routehandler do
  require Logger

  alias Routing.Routecalc

  def calc_delivery(payload) do
    {status, data} = process_message(payload)
    cond do
      status == :err ->
        {:err, data}
      !verify_data(data) ->
        {:err, "Invalid data for delivery found: #{data}"}
      true ->
        Logger.info("Order for: ID: #{data["id"]}: #{data["from"]}, #{data["to"]}")
        calc_route(data, true)
        {:ok, "Route successfully calculated"}
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
        calc_route(data, false)
        {:ok, "Route successfully calculated"}
    end
  end

  defp calc_route(data, delivery) do
    Routecalc.calc(data, delivery)
  end

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

