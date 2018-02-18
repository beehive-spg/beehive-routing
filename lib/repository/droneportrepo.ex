defmodule Routing.Droneportrepo do
  require Logger

  # TODO implement as GenServer
  # Even method paramenters need to be changed for proper implementation

  def get_predictions_for(buildings, time) when is_list(buildings) do
    map_predictions(buildings, 1)
  end

  defp map_predictions([], _value), do: %{}
  defp map_predictions([h | t], value) do
    map_predictions(t, value) |> Map.merge(%{h => value})
  end

  def get_predicted_cost_factor(data, building, :take) do
    Map.get(data, building)
  end
  def get_predicted_cost_factor(data, building, :give) do
    Map.get(data, building)
  end

end
