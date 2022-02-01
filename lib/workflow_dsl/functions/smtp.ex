defmodule WorkflowDsl.Smtp do

  require Logger

  # NOTE: Deprecated
  def send(params) do
    Logger.log(:debug, "[DEPRECATED] execute :send, params: #{inspect params}")
  end
end
