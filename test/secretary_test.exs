ExUnit.start

defmodule SecretaryTest do
    use ExUnit.Case, async: false
    doctest Routing.Secretary
    alias Routing.Redixcontrol

    test "Executing arrival" do
        time = "1990-01-01 00:00:00"
        drone = "12"
        hive = "12"
        is_delivery = true

        id = Redixcontrol.add_arrival(time, drone, hive, is_delivery)
        Routing.Secretary.check
        assert Redixcontrol.query(["HGET", "arr_#{id}", "drone"]) == nil
    end

    test "Executing departure" do
        time = "2000-01-01 00:00:00"
        drone = "12"
        hive = "12"
        is_delivery = true

        id = Redixcontrol.add_departure(time, drone, hive, is_delivery)
        Routing.Secretary.check
        assert Redixcontrol.query(["HGET", "arr_#{id}", "drone"]) == nil
    end
end
