use Mix.Config

config :logger, 
	level: :warn, #for runtime
	truncate: 4096,
	compile_time_purge_level: :info, #for compile time
	backends: [:console]

