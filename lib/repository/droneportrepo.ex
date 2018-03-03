defmodule Routing.Droneportrepo do
  require Logger

  alias Routing.Dronerepo

  # TODO implement as GenServer
  # Even method paramenters need to be changed for proper implementation

  @url Application.fetch_env!(:routing, :database_url)

  def get_predictions_for(buildings, time) when is_list(buildings) do
    result = case HTTPotion.get(@url <> "/api/hivecosts?#{build_ids(buildings, time)}") do
      %{:body => b, :headers => _, :status_code => 200} ->
        Logger.debug("Fetching costs for hives succeeded with code 200")
        Poison.decode!(~s/#{b}/)
      %{:body => b, :headers => _, :status_code => s} ->
        Logger.error("Fetching hive costs returned a bad status code: #{s} with error message #{b}")
    end
    map_predictions(result)
  end

  defp build_ids([], time), do: "time=#{time}"
  defp build_ids([id | t], time) do
    id = Regex.replace(~r/[A-Za-z]*/, "#{id}", "")
    "ids=#{id}&" <> build_ids(t, time)
  end

  defp map_predictions([]), do: %{}
  defp map_predictions([h | t]), do: map_predictions(t) |> Map.merge(%{:"dp#{h["db/id"]}" => h["hive/cost"]})

  def get_predicted_cost_factor(data, building, :take) do
    result = Map.get(data, building)
    case result do
      nil -> 1
      _ -> result
    end
  end

  def get_predicted_cost_factor(data, building, :give) do
    round(1 - get_predicted_cost_factor(data, building, :take) / 20)
  end

  def pass_packet_costs(data, building, after_distance) do
    charge_loss = after_distance / Dronerepo.get_dronerange(0) |> IO.inspect
    IO.puts "#{building}"
    round(((1 - charge_loss) * get_predicted_cost_factor(data, building, :take))*10000)/10000
  end
end

