defmodule WorkflowDsl.File do

  require Logger
  alias WorkflowDsl.Storages
  alias WorkflowDsl.Lang
  alias WorkflowDsl.MathExprParser

  def write(params) do
    Logger.debug("execute :write #{inspect params}")

    func = Storages.get_last_function_by(%{"module" => __MODULE__, "name" => :write})
    parameters = Enum.map(params, fn [k,v] ->
      {k, eval_var(func.session, v)}
    end)
    |> Enum.into(%{})

    with true <- Map.has_key?(parameters, "input"),
      true <- Map.has_key?(parameters, "output_path"),
      :ok <- File.mkdir_p(Path.dirname(parameters["output_path"])) do
        File.write(parameters["output_path"], parameters["input"])
    end
  end

  defp eval_var(session, var) do
    if is_binary(var) and String.starts_with?(var, "${") do
      {:ok, [res], _, _, _, _} = MathExprParser.parse_math(var)
      Lang.eval(session, res)
    else
      var
    end
  end

end
