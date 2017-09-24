defmodule Buffer.Redixcontrol do
	use Supervisor
	require Logger

	def start_link(opts) do
		Supervisor.start_link(__MODULE__, :ok, opts)
	end

	def init(:ok) do
		poolsize = 3
		host = Application.fetch_env!(:redix, :host)
		port = Application.fetch_env!(:redix, :port)

		pool = for i <- 0..(poolsize-1) do
			args = [[host: host, port: port], [name: :"redix_#{i}"]]
			Supervisor.child_spec({Redix, args}, id: {Redix, i})
		end

		opts = [strategy: :one_for_one, name: Buffer.Redixcontrol]
		#ret = Supervisor.init(pool, opts)
		Supervisor.init(pool, opts)
	end

	# Not used, because up to now we want to set up the database manually
	defp init_db() do
		if get("init") == nil do
			set("arr_next_id", "0")
			set("dep_next_id", "0")
		end
	end

	def query(command) when is_list(command) do
		name = :"redix_#{randomize()}"

		Logger.info("Executing #{command} on instance #{name}")
		{status, resp} = Redix.command(:"redix_#{randomize()}", command)
		Logger.info("Command executed. Status: #{status}")

		resp
	end

	def add_arrival(time, drone, hive, is_delivery) do
		query ["MULTI"] # start transaction

		query ["HSET", "arr_#{get "arr_next_id"}", "time", "#{time}", "drone", "#{drone}", "hive", "#{hive}", "is_delivery", "#{is_delivery}"]
		query ["INCR", "arr_next_id"]

		query ["EXEC"] # commit changes
	end

	def add_departure(time, drone, hive, is_delivery) do
		query ["MULTI"] # start transaction

		query ["HSET", "dep_#{get "dep_next_id"}", "time", "#{time}", "drone", "#{drone}", "hive", "#{hive}", "is_delivery", "#{is_delivery}"]
		query ["INCR", "dep_next_id"]

		query ["EXEC"] # commit
	end

	def remove_arrival(key) do
		
	end

	def remove_departure(key) do
		
	end

	def get(key) do
		query ["GET", "#{key}"]
	end

	def set(key, value) do
		query ["SET", "#{key}", "#{value}"]
	end

	defp randomize() do
		rem(System.unique_integer([:positive]), 3)
	end

	defp add_to_list(list, value) do
		query ["RPUSH", "#{list}", "#{value}"]
	end

	defp remove_from_list(list, value) do
		query ["LREM", "-1", "#{value}"]
	end
end