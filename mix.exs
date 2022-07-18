defmodule WorkflowDsl.MixProject do
  use Mix.Project

  def project do
    [
      app: :workflow_dsl,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
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
      {:etso, "~> 1.0"},
      # {:ecto_sqlite3, "~> 0.7.5"},
      {:nimble_parsec, "~> 1.0"},
      {:nimble_csv, "~> 1.2"},
      {:req, git: "https://github.com/wojtekmach/req.git"},
      {:bypass, "~> 2.1", only: :test},
    ]
  end
  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      "sqlite.test": ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
    ]
  end
end
