use Mix.Config

config :routing,
  cloudamqp_url: System.get_env("CLOUDAMQP_URL") # TODO implement confex

config :logger,
  level: :debug,
  truncate: 4096,
  compile_time_purge_level: :debug,
  backends: [:console]
