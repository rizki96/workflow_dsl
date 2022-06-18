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

  def string(params) do
    Logger.log(:debug, "execute :string, params: #{inspect params}")

    func = Storages.get_last_function_by(%{"module" => __MODULE__, "name" => :string})
    parameters = Enum.map(params, fn [k,v] ->
      {k, Lang.eval(func.session, v)}
    end)
    |> Enum.into(%{})

    display =
      with true <- Map.has_key?(parameters, "command") do
        parameters["command"]
      else
        _ -> "head"
      end

    line_count =
      with true <- Map.has_key?(parameters, "line_displayed_count") do
        parameters["line_displayed_count"]
      else
        _ -> 0
      end

    text =
      with true <- Map.has_key?(parameters, "input_string") do
        parameters["input_string"]
      else
        _ -> ""
      end

    like =
      with true <- Map.has_key?(parameters, "match") do
        parameters["match"]
      else
        _ -> ""
      end

    device =
      with true <- Map.has_key?(parameters, "display_device") do
        String.to_existing_atom(parameters["display_device"])
      else
        _ -> :stdio
      end

    output =
    case display do
      "head" ->
        case line_count do
          0 -> text
          n ->
            String.split(text, "\n")
            |> Enum.take(n)
            |> Enum.join("\n")
        end
      "tail" ->
        case line_count do
          0 -> text
          n ->
            String.split(text, "\n")
            |> Enum.take(-n)
            |> Enum.join("\n")
        end
      "grep" ->
        grep_list =
          String.split(text, "\n")
          |> Enum.filter(fn it ->
            it =~ like
          end)
        case line_count do
          0 -> grep_list
          n -> Enum.take(grep_list, n)
        end
        |> Enum.join("\n")
      _ -> text
    end

    IO.puts(device, output)
    {:ok, output}
  end

  def log(params) do
    Logger.log(:debug, "execute :log, params: #{inspect params}")
    func = Storages.get_last_function_by(%{"module" => __MODULE__, "name" => :log})
    parameters = Enum.map(params, fn [k,v] ->
      {k, Lang.eval(func.session, v)}
    end)
    |> Enum.into(%{})

    text =
      with true <- Map.has_key?(parameters, "text") do
        parameters["text"]
      else
        _ -> ""
      end

    device =
      with true <- Map.has_key?(parameters, "display_device") do
        String.to_existing_atom(parameters["display_device"])
      else
        _ -> :stdio
      end

    IO.puts(device, text)
      {:ok, text}
  end
end
