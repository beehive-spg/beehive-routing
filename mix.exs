defmodule Routing.Mixfile do
  use Mix.Project

  def project do
    [
      app: :routing,
      version: "0.2.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {Routing, []},
      applications: [:logger, :redix, :timex, :amqp, :conform, :crontab, :gen_stage, :graphbrewer, :poison, :quantum, :httpotion, :httpoison, :distance],
    ]
  end

  defp deps do
    [
      # Source Management
      {:conform, "~> 2.5", override: true},
      {:distillery, "~> 1.5", runtime: false},

      # Graph Management
      {:graphbrewer, "~> 0.1.8"},

      # RabbitMQ / CloudAMQP
      {:amqp, "~> 1.0.0-pre.2"},

      # JSON
      {:poison, "~> 3.1"},

      # Redis
      {:redix, git: "https://github.com/whatyouhide/redix.git"},

      # Job Scheduling
      {:quantum, ">= 2.2.3"},
      {:timex, "~> 3.1.13"},

      # HTTP requests
      {:httpotion, git: "https://github.com/myfreeweb/httpotion.git", branch: "master"},
      {:httpoison, "1.1.0"},

      # Distance Calculation
      {:distance, "~> 0.2.1"}
    ]
  end
end
