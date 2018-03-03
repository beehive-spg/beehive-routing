defmodule Routing.Dronerepo do
  require Logger

  def get_drone(id) do
    case HTTPotion.get("#{Application.fetch_env!(:routing, :database_url)}/drones?id=#{id}") do
      %{:body => b, :headers => _, :status_code => 200} ->
        Logger.debug("Fetching drone succeded with code 200")
        Enum.at(Poison.decode!(~s/#{b}/), 0) # Enum.at temporary fix to enable fetching one obj
        # Add the drone type to the map
      %{:body => _, :headers => _, :status_code => s} ->
        Logger.error("Fetching drone #{id} returned a bad status code: #{s}")
    end
  end

  # TODO methods currently return static value as of the bad return value of the /drones route

  def get_dronespeed(_id) do
    15
    # drone = get_drone(id)
  end

  def get_dronerange(_id) do
    5000
    # drone = get_drone(id)
  end

  def get_dronechargetime(_id) do
    1800
    # drone = get_drone(id)
  end

end
