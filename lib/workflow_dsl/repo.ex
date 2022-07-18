defmodule WorkflowDsl.Repo do
  use Ecto.Repo, otp_app: :workflow_dsl, adapter: Etso.Adapter
  # NOTE: uncomment below line and comment above line for using sqlite,
  # use Ecto.Repo, otp_app: :workflow_dsl, adapter: Ecto.Adapters.SQLite3
end
