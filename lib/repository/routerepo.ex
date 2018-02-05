defmodule Routing.Routerepo do

  def get_real_data(route) do
    data = Poison.encode!(route)
    route
  end

  def insert_route(route) do
    data = transform_to_db_format(route) |> Poison.encode!
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

end
