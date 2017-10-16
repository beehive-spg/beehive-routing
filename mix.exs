defmodule Buffer.Mixfile do
  use Mix.Project

  def project do
    [
      app: :buffer,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      applications: [:logger, :redix, :timex],
      mod: {Buffer, []}
    ]
  end

  defp deps do
    [
      # Source Management
      {:conform, "~> 2.5", override: true},
      {:exrm, "~> 1.0", override: true},
      {:conform_exrm, "~> 1.0"},

      # Redis
      {:redix, git: "https://github.com/whatyouhide/redix.git"},

      # Job Scheduling
      {:quantum, ">= 2.1.0"},
      {:timex, "~> 3.1"}
    ]
  end
end
