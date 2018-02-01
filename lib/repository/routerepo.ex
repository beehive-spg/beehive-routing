defmodule Routing.Routerepo do

  def get_real_data(route) do
    data = Poison.encode!(route)
    route
  end

  def insert_route(route) do
    data = Poison.encode!(route)
  end

end
