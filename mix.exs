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

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Routing, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:conform, "~> 2.5", override: true},
      {:exrm, "~> 1.0", override: true},
      {:conform_exrm, "~> 1.0"},

      # Graph Management
      # {:libgraph, "~> 0.11.1"}
      #{:libgraph, git: "git@github.com:Langhaarzombie/libgraph.git"}
      #{:libgraph, git: "https://github.com/Langhaarzombie/libgraph.git", branch: "develop"}
      {:graph, git: "https://github.com/Langhaarzombie/graph-brewer.git", branch: "develop"}
    ]
  end
end
