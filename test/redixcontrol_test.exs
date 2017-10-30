ExUnit.start

defmodule RedixcontrolTest do
    use ExUnit.Case, async: true
    doctest Buffer.Redixcontrol

    # NOTE Make sure the Redis Server is started

    test "Worker creation and operability." do
        assert Buffer.Redixcontrol.query(["PING"]) == "PONG"
    end

    test "Redis operability. Insert \"fav_color: green\"" do
        key = "fav_color"
        value = "green"

        Buffer.Redixcontrol.set(key, value)
        result = Buffer.Redixcontrol.get(key)
        Buffer.Redixcontrol.query(["DEL", "#{key}"])

        assert result == value
    end

    test "Adding and removing arrivals" do
        time = "2017-01-01 12:00:00"
        drone = "512"
        location = "16"
        is_delivery = true

        id = Buffer.Redixcontrol.add_arrival(time, drone, location, is_delivery)
        resp = Buffer.Redixcontrol.query ["HGET", "arr_#{id}", "drone"]
        assert resp == drone
        Buffer.Redixcontrol.remove_arrival("arr_#{id}")
        assert Buffer.Redixcontrol.query(["HGET", "arr_#{id}", "drone"]) == nil
    end

    test "Adding and removing departures" do
        time = "2017-01-01 12:00:00"
        drone = "512"
        location = "16"
        is_delivery = true

        id = Buffer.Redixcontrol.add_departure(time, drone, location, is_delivery)
        resp = Buffer.Redixcontrol.query ["HGET", "dep_#{id}", "drone"]
        assert resp == drone
        Buffer.Redixcontrol.remove_departure("dep_#{id}")
        assert Buffer.Redixcontrol.query(["HGET", "dep_#{id}", "drone"]) == nil
    end

    test "Adding routes" do
        route = %{:is_delivery => true, :route => [%{:from => "10", :to => "11", :dep_time => "2017-01-01 10:00:00", :arr_time => "2017-01-01 10:10:00", :drone => "512"}, %{:from => "11", :to => "12", :dep_time => "2017-01-01 10:20:00", :arr_time => "2017-01-01 10:35:00", :drone => "26"}]}
        ids = Buffer.Redixcontrol.add_route(route)
        assert Buffer.Redixcontrol.query(["HGET", "dep_#{Enum.at(Enum.at(ids, 0), 0)}", "arrival"]) == "arr_#{Enum.at(Enum.at(ids, 0), 1)}"
        cleanup(ids)
    end

    defp cleanup([head | []]) do
        Buffer.Redixcontrol.remove_departure("dep_#{Enum.at(head, 0)}")
        Buffer.Redixcontrol.remove_arrival("arr_#{Enum.at(head, 1)}")
    end

    defp cleanup([head | tail]) do
        Buffer.Redixcontrol.remove_departure("dep_#{Enum.at(head, 0)}")
        Buffer.Redixcontrol.remove_arrival("arr_#{Enum.at(head, 1)}")
        cleanup(tail)
    end
end
