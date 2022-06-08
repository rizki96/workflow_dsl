defmodule WorkflowDsl.File do

  require Logger
  alias WorkflowDsl.Lang
  alias WorkflowDsl.Storages
  # alias WorkflowDsl.MathExprParser
  alias NimbleCSV.RFC4180, as: CSV


  def write(params) do
    Logger.debug("execute :write #{inspect params}")

    func = Storages.get_last_function_by(%{"module" => __MODULE__, "name" => :write})
    parameters = Enum.map(params, fn [k,v] ->
      {k, Lang.eval(func.session, v)}
    end)
    |> Enum.into(%{})

    options = [:write]

    options =
    with true <- Map.has_key?(parameters, "utf8") do
      if parameters["utf8"] == true, do: options ++ [:utf8], else: options
    else
      _ -> options
    end

    options =
    with true <- Map.has_key?(parameters, "append") do
      if parameters["append"] == true, do: options ++ [:append], else: options
    else
      _ -> options
    end

    options =
    with true <- Map.has_key?(parameters, "binary") do
      if parameters["binary"] == true, do: options ++ [:binary], else: options
    else
      _ -> options
    end

    with true <- Map.has_key?(parameters, "input_string"),
      true <- Map.has_key?(parameters, "output_path"),
      :ok <- File.mkdir_p(Path.dirname(parameters["output_path"])) do
        File.write(parameters["output_path"], parameters["input_string"], options)
    end

    with true <- Map.has_key?(parameters, "input_path"),
      true <- Map.has_key?(parameters, "output_path"),
      :ok <- File.mkdir_p(Path.dirname(parameters["output_path"])) do
        input_file = File.read!(parameters["input_path"])
        File.write(parameters["output_path"], input_file, options)
    end

    with true <- Map.has_key?(parameters, "input_url"),
      true <- Map.has_key?(parameters, "output_path"),
      :ok <- File.mkdir_p(Path.dirname(parameters["output_path"])) do
        if String.starts_with?(parameters["input_url"], ["http://", "https://"]) do
          {:ok, content} = Req.request(:get, parameters["input_url"])
          File.write(parameters["output_path"], content.body, options)
        end
    end
  end

  def read(params) do
    Logger.debug("execute :read #{inspect params}")

    func = Storages.get_last_function_by(%{"module" => __MODULE__, "name" => :read})
    parameters = Enum.map(params, fn [k,v] ->
      {k, Lang.eval(func.session, v)}
    end)
    |> Enum.into(%{})

    read_as =
      with true <- Map.has_key?(parameters, "read_as") do
        case parameters["read_as"] do
          "json" -> fn x -> {:ok, json_parse(x)} end
          "csv" -> fn x -> {:ok, csv_parse(x)} end
          "text" -> fn x -> {:ok, x} end
          _ -> fn x -> {:ok, x} end
        end
      else
        _ -> fn x -> {:ok, x} end
      end

    result =
    with true <- Map.has_key?(parameters, "input_path") do
      File.read!(parameters["input_path"])
      |> read_as.()
    end

    with true <- Map.has_key?(parameters, "input_url") do
      if String.starts_with?(parameters["input_url"], ["http://", "https://"]) do
        {:ok, content} = Req.request(:get, parameters["input_url"])
        read_as.(content.body)
      end
    else
      _ -> result
    end
  end

  defp json_parse(input) do
    Jason.decode!(input)
  end

  defp csv_parse(input) do
    [header] = input
      |> CSV.parse_string(skip_headers: false)
      |> Stream.map(fn row -> row end)
      |> Enum.take(1)
    input
      |> CSV.parse_string(skip_headers: true)
      |> Enum.map(fn row -> Enum.zip(header, row) |> Enum.into(%{}) end)
      |> Enum.reduce(%{}, fn (item, acc) ->
        case acc do
          %{} -> Enum.map(item, fn {k,v} -> {k, [v]} end)
          t -> Enum.map(t, fn {k,v} -> {k, v ++ [item[k]]} end)
        end
      end) |> Enum.into(%{})
  end
end
