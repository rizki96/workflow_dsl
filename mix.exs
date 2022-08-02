defmodule WorkflowDsl.MixProject do
  use Mix.Project

  def project do
    [
      app: :workflow_dsl,
      version: "0.4.6",
      elixir: "~> 1.10",
      description: "Domain specific language based on Google Cloud Workflows",
      package: package(),
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
      {:req, "~> 0.3.0"},
      {:bypass, "~> 2.1", only: :test},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
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

  defp package() do
    [
      # This option is only needed when you don't want to use the OTP application name
      name: "workflow_dsl",
      # These are the default files included in the package
      files: ~w(lib priv mix.exs README* LICENSE* config examples),
      licenses: ["LGPL-2.1"],
      links: %{"GitHub" => "https://github.com/rizki96/workflow_dsl"}
    ]
  end
end
