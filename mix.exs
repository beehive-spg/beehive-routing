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

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      applications: [:logger, :redix],
      mod: {Buffer, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Source Management
      {:conform, "~> 2.5", override: true},
      {:exrm, "~> 1.0", override: true},
      {:conform_exrm, "~> 1.0"},

      # Other
      # {:redix, "~> 0.6.1"} # Redis Hex
      {:redix, git: "https://github.com/whatyouhide/redix.git"}
    ]
  end
end
