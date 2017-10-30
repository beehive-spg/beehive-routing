ExUnit.start

defmodule SecretaryTest do
    use ExUnit.Case, async: false
    doctest Buffer.Secretary

    test "Executing arrival" do
        time = "1990-01-01 00:00:00"
        drone = "12"
        hive = "12"
        is_delivery = true

        id = Buffer.Redixcontrol.add_arrival(time, drone, hive, is_delivery)
        Buffer.Secretary.check
        assert Buffer.Redixcontrol.query(["HGET", "arr_#{id}", "drone"]) == nil
    end

    test "Executing departure" do
        time = "2000-01-01 00:00:00"
        drone = "12"
        hive = "12"
        is_delivery = true

        id = Buffer.Redixcontrol.add_departure(time, drone, hive, is_delivery)
        Buffer.Secretary.check
        assert Buffer.Redixcontrol.query(["HGET", "arr_#{id}", "drone"]) == nil
    end
end
