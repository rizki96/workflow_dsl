defmodule WorkflowDsl.Repo do
  use Ecto.Repo,
    otp_app: :workflow_dsl,
    adapter: Etso.Adapter
end
