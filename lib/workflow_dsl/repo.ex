defmodule WorkflowDsl.Repo do
  use Ecto.Repo,
    otp_app: :dsl_test,
    adapter: Etso.Adapter
end
