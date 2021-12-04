defmodule WorkflowDsl.MixProject do
  use Mix.Project

  def project do
    [
      app: :workflow_dsl,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {WorkflowDsl.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps() do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:jason, "~> 1.0"},
      {:etso, "~> 0.1.5"},
      {:nimble_parsec, "~> 1.0"},
      {:req, git: "https://github.com/wojtekmach/req.git"},
      {:bypass, "~> 2.1", only: :test},
    ]
  end
end
