import Config

config :workflow_dsl,
  ecto_repos: [WorkflowDsl.Repo]

config :workflow_dsl, WorkflowDsl.Repo,
  database: "priv/data/workflow.db",
  log: false
