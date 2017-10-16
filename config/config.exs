use Mix.Config

config :logger,
	level: :debug, #for runtime
	truncate: 4096,
	compile_time_purge_level: :debug, #for compile time
	backends: [:console]

config :redix,
	host: "localhost",
	port: 6379 # default

config :buffer,
	datetime_format: "{ISO:Extended}"

# TODO check if it is possible to set Vienna as timezone
config :buffer, Buffer.Secretary,
	overlap: false,
	timezone: :utc,
	jobs: [
		check_for_job: [
			schedule: {:extended, "*/1"}, # runs every second
			task: {Buffer.Secretary, :check, []}
		]
	]
