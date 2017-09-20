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

		Supervisor.init(pool, strategy: :one_for_one)
	end

	def query(command) do
		name = :"redix_#{randomize()}"

		Logger.info("Executing #{command} on instance #{name}")
		{status, resp} = Redix.command(:"redix_#{randomize()}", command)
		Logger.info("Command executed. Status: #{status}")

		resp
	end

	def randomize() do
		rem(System.unique_integer([:positive]), 3)
	end
end