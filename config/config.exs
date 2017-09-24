use Mix.Config

config :logger, 
	level: :warn, #for runtime
	truncate: 4096,
	compile_time_purge_level: :info, #for compile time
	backends: [:console]

config :redix,
	host: "localhost",
	port: 6379 # default

config :buffer, Buffer.Secretary,
	overlap: false,
	timezone: :utc, # TODO check if it is possible to set Vienna as timezone
	jobs: [
		check_for_job: [
			schedule: {:extended, "*/1"}, # runs every second
			task: {Buffer.Secretary, :check, []}
		]
	]