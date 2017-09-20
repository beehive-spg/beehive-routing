ExUnit.start

defmodule RedixcontrolTest do
	use ExUnit.Case, async: true
	doctest Buffer.Redixcontrol

	# Make sure the Redis Server is started

	test "Worker creation and operability." do
		Buffer.Redixcontrol.start_link(name: Buffer.Redixcontrol)
		assert Buffer.Redixcontrol.query(["PING"]) == "PONG"
	end

	test "Redis operability. Insert \"fav_color: green\"" do
		key = "fav_color"
		value = "green"

		Buffer.Redixcontrol.start_link(name: Buffer.Redixcontrol)
		Buffer.Redixcontrol.query(["SET", "#{key}", "#{value}"])
		result = Buffer.Redixcontrol.query(["GET", "#{key}"])
		Buffer.Redixcontrol.query(["DEL", "#{key}"])
		
		assert result == value
	end
end
