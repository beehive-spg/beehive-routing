use Mix.Config

config :routing,
  cloudamqp_url: System.get_env("CLOUDAMQP_URL") # TODO implement confex

config :logger,
	level: :debug, #for runtime
	truncate: 4096,
	compile_time_purge_level: :debug, #for compile time
	backends: [:console]

config :redix,
    host: "pub-redis-13146.eu-central-1-1.1.ec2.redislabs.com",
	port: 13146,
    password: System.get_env("REDIS_PWD") # TODO implement confex

config :timex,
	datetime_format: "{ISO:Extended}"

config :routing, Routing.Secretary,
	overlap: false,
	timezone: :utc,
	jobs: [
		check_for_job: [
			schedule: {:extended, "*/1"}, # runs every second
			task: {Routing.Secretary, :check, []}
		]
	]
