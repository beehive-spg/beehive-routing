defmodule Routing.Mixfile do
  use Mix.Project

  def project do
    [
      app: :routing,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {Routing, []},
      applications: [:logger, :redix, :timex, :amqp],
    ]
  end

  defp deps do
    [
      # Source Management
      {:conform, "~> 2.5", override: true},
      {:exrm, "~> 1.0", override: true},
      {:conform_exrm, "~> 1.0"},

      # Graph Management
      {:graphbrewer, "~> 0.1.1"},

      # RabbitMQ / CloudAMQP
      {:amqp, "~> 1.0.0-pre.2"},

      # JSON
      {:poison, "~> 3.1"},

      # Redis
      {:redix, git: "https://github.com/whatyouhide/redix.git"},

      # Job Scheduling
      {:quantum, ">= 2.1.0"},
      {:timex, "~> 3.1"}
    ]
  end
end
