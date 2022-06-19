import Config

config :workflow_dsl,
  ecto_repos: [WorkflowDsl.Repo],
  log_level: :info

config :workflow_dsl, WorkflowDsl.Repo,
  database: "priv/data/workflow.db",
  log: false
