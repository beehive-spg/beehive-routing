ExUnit.start

defmodule RedixcontrolTest do
    use ExUnit.Case, async: true
    doctest Routing.Redixcontrol

    # NOTE Make sure the Redis Server is started

    test "Worker creation and operability." do
        assert Routing.Redixcontrol.query(["PING"]) == "PONG"
    end

    test "Redis operability. Insert \"fav_color: green\"" do
        key = "fav_color"
        value = "green"

        Routing.Redixcontrol.set(key, value)
        result = Routing.Redixcontrol.get(key)
        Routing.Redixcontrol.query(["DEL", "#{key}"])

        assert result == value
    end

    test "Adding and removing arrivals" do
        time = "2017-01-01 12:00:00"

        id = Routing.Redixcontrol.add_arrival(time)
        resp = Routing.Redixcontrol.query ["HGET", "arr_#{id}", "time"]
        assert resp == time
        Routing.Redixcontrol.remove_arrival("arr_#{id}")
        assert Routing.Redixcontrol.query(["HGET", "arr_#{id}", "time"]) == nil
    end

    test "Adding and removing departures" do
        time = "2017-01-01 12:00:00"

        id = Routing.Redixcontrol.add_departure(time)
        resp = Routing.Redixcontrol.query ["HGET", "dep_#{id}", "time"]
        assert resp == time
        Routing.Redixcontrol.remove_departure("dep_#{id}")
        assert Routing.Redixcontrol.query(["HGET", "dep_#{id}", "time"]) == nil
    end

    test "Adding routes" do
        route = [%{:dep_time => "2017-01-01 10:00:00", :arr_time => "2017-01-01 10:10:00"}, %{:dep_time => "2017-01-01 10:20:00", :arr_time => "2017-01-01 10:35:00"}]
        ids = Routing.Redixcontrol.add_route(route)
        assert Routing.Redixcontrol.query(["HGET", "dep_#{Enum.at(Enum.at(ids, 0), 0)}", "arrival"]) == "arr_#{Enum.at(Enum.at(ids, 0), 1)}"
        cleanup(ids)
    end

    defp cleanup([head | []]) do
        Routing.Redixcontrol.remove_departure("dep_#{Enum.at(head, 0)}")
        Routing.Redixcontrol.remove_arrival("arr_#{Enum.at(head, 1)}")
    end

    defp cleanup([head | tail]) do
        Routing.Redixcontrol.remove_departure("dep_#{Enum.at(head, 0)}")
        Routing.Redixcontrol.remove_arrival("arr_#{Enum.at(head, 1)}")
        cleanup(tail)
    end
end

