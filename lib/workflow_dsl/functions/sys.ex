defmodule WorkflowDsl.Sys do

  require Logger
  alias WorkflowDsl.Lang
  alias WorkflowDsl.Storages

  def sleep(params) do
    Logger.log(:debug, "execute :sleep, params: #{inspect params}")

    func = Storages.get_last_function_by(%{"module" => __MODULE__, "name" => :sleep})
    parameters = Enum.map(params, fn [k,v] ->
      {k, Lang.eval(func.session, v)}
    end)
    |> Enum.into(%{})

    time =
      with true <- Map.has_key?(parameters, "time_in_secs") do
        parameters["time_in_secs"]
      else
        _ -> 0
      end

    Process.sleep(time * 1000)
  end

  def log(params) do
    Logger.log(:debug, "execute :log, params: #{inspect params}")

    func = Storages.get_last_function_by(%{"module" => __MODULE__, "name" => :log})
    parameters = Enum.map(params, fn [k,v] ->
      {k, Lang.eval(func.session, v)}
    end)
    |> Enum.into(%{})

    display =
      with true <- Map.has_key?(parameters, "head_or_tail") do
        parameters["head_or_tail"]
      else
        _ -> "head"
      end

    line_count =
      with true <- Map.has_key?(parameters, "line_count") do
        parameters["line_count"]
      else
        _ -> 0
      end

    text =
      with true <- Map.has_key?(parameters, "text") do
        parameters["text"]
      else
        _ -> ""
      end

    device =
      with true <- Map.has_key?(parameters, "device") do
        String.to_existing_atom(parameters["device"])
      else
        _ -> :stdio
      end


    output =
    case display do
      "head" ->
        String.split(text, "\n")
        |> Enum.take(line_count)
        |> Enum.join("\n")
      "tail" ->
        String.split(text, "\n")
        |> Enum.take(-line_count)
        |> Enum.join("\n")
      _ ->
        String.split(text, "\n")
        |> Enum.take(line_count)
        |> Enum.join("\n")
    end

    IO.puts(device, output)
    {:ok, output}
  end
end
