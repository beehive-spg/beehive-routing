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
        hive = "16"
        is_delivery = true

        id = Buffer.Redixcontrol.add_arrival(time, drone, hive, is_delivery)
        resp = Buffer.Redixcontrol.query ["HGET", "arr_#{id}", "drone"]
        assert resp == drone
        Buffer.Redixcontrol.remove_arrival("arr_#{id}")
        assert Buffer.Redixcontrol.query(["HGET", "arr_#{id}", "drone"]) == nil
    end

    test "Adding and removing departures" do
        time = "2017-01-01 12:00:00"
        drone = "512"
        hive = "16"
        is_delivery = true

        id = Buffer.Redixcontrol.add_departure(time, drone, hive, is_delivery)
        resp = Buffer.Redixcontrol.query ["HGET", "dep_#{id}", "drone"]
        assert resp == drone
        Buffer.Redixcontrol.remove_departure("dep_#{id}")
        assert Buffer.Redixcontrol.query(["HGET", "dep_#{id}", "drone"]) == nil
    end


end
