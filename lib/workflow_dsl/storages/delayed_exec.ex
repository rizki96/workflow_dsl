defmodule WorkflowDsl.Storages.DelayedExec do
  use Agent

  def start_link(_args) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def value(session) do
    Agent.get(__MODULE__, fn m ->
      if Map.has_key?(m, session) do
        m[session]
      end
    end)
  end

  def reset(session, value) do
    Agent.update(__MODULE__, fn m ->
      if Map.has_key?(m, session), do: Map.put(m, session, value), else: Map.put_new(m, session, value)
    end)
  end
end
