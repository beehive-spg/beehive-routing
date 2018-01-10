use Mix.Config

config :routing,
  cloudamqp_url: System.get_env("CLOUDAMQP_URL")

config :logger,
	level: :debug, #for runtime
	truncate: 4096,
	compile_time_purge_level: :info, #for compile time
	backends: [:console]

config :redix,
    # host: "localhost",
    host: "redis",
    port: 6379

config :timex,
	datetime_format: "{ISO:Extended}"

config :tzdata, :autoupdate, :disabled

config :routing, Routing.Secretary,
	overlap: false,
	timezone: :utc,
	jobs: [
		check_for_job: [
			schedule: {:extended, "*/1"}, # runs every second
			task: {Routing.Secretary, :check, []}
		]
	]
