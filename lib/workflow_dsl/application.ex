defmodule WorkflowDsl.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Starts a worker by calling: WorkflowDsl.Worker.start_link(arg)
      # {WorkflowDsl.Worker, arg}
      {WorkflowDsl.Storages.DelayedExec, []},
      %{
        id: WorkflowDsl.Repo,
        start: {WorkflowDsl.Repo, :start_link, []}
      },
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: WorkflowDsl.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
