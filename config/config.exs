use Mix.Config

config :routing,
  cloudamqp_url: System.get_env("CLOUDAMQP_URL") # TODO implement confex

config :logger,
	level: :debug, #for runtime
	truncate: 4096,
	compile_time_purge_level: :debug, #for compile time
	backends: [:console]

config :redix,
	host: "localhost",
	port: 6379 # default

config :timex,
	datetime_format: "{ISO:Extended}"

# TODO check if it is possible to set Vienna as timezone
config :routing, Routing.Secretary,
	overlap: false,
	timezone: :utc,
	jobs: [
		check_for_job: [
			schedule: {:extended, "*/1"}, # runs every second
			task: {Routing.Secretary, :check, []}
		]
	]
