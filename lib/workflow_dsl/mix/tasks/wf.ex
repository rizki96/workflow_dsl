defmodule Mix.Tasks.Wf do

  alias WorkflowDsl.Utils.Randomizer

  defmodule Run do
    use Mix.Task
    @moduledoc """
    Running the JSON workflow DSL

    Command: mix wf.run <json workflow file path / URL> [--verbose] [--execute subworkflow-name] [--json-args json-body]

        script file path / URL     : json formatted script that will be executed
        --verbose                  : display debug information
        --execute subworkflow-name : execute specific subworkflow name that exists in script
        --json-args json-body      : add input parameters for subworkflow in json format
    """
    @shortdoc "Running the JSON workflow DSL"

    @impl Mix.Task
    def run(args) do
      parsed_args = OptionParser.parse(args, switches: [verbose: :boolean, execute: :string, json_args: :string])
      case parsed_args do
        {[verbose: verbose, execute: subworkflow, json_args: json_args], [input], _} ->
          if verbose, do: Logger.configure(level: :debug), else: Logger.configure(level: :info)
          {:ok, _} = Application.ensure_all_started(:workflow_dsl)

          case Jason.decode(json_args) do
            {:ok, args} ->
              run_process(input, subworkflow, args) |> clear_session()
              IO.puts("\n#{input} is executed\n")
            _ ->
              IO.puts("\nnot in a json formatted input for json-args argument: #{json_args}\n")
          end

        {[verbose: verbose, execute: subworkflow], [input], _} ->
          if verbose, do: Logger.configure(level: :debug), else: Logger.configure(level: :info)
          {:ok, _} = Application.ensure_all_started(:workflow_dsl)

          run_process(input, subworkflow) |> clear_session()
          IO.puts("\n#{input} is executed\n")

        {[verbose: verbose, json_args: json_args], [input], _} ->
          if verbose, do: Logger.configure(level: :debug), else: Logger.configure(level: :info)
          {:ok, _} = Application.ensure_all_started(:workflow_dsl)

          case Jason.decode(json_args) do
            {:ok, args} ->
              run_process(input, "", args) |> clear_session()
              IO.puts("\n#{input} is executed\n")
            _ ->
              IO.puts("\nnot in a json formatted input for json-args argument: #{json_args}\n")
          end

        {[verbose: verbose], [input], _} ->
          if verbose, do: Logger.configure(level: :debug), else: Logger.configure(level: :info)
          {:ok, _} = Application.ensure_all_started(:workflow_dsl)

          run_process(input) |> clear_session()
          IO.puts("\n#{input} is executed\n")

        _ ->
          IO.puts("\nRunning the JSON workflow DSL
\nCommand: mix wf.run <script file path / URL> [--verbose] [--execute subworkflow-name] [--json-args json-body]
\n    script file path / URL     : json formatted script that will be executed
    --verbose                  : display debug information
    --execute subworkflow-name : execute specific subworkflow name that exists in script
    --json-args json-body      : add input parameters for subworkflow in json format
            ")
      end
    end

    defp run_process(input, subworkflow_name \\ "", args_body \\ %{}) do
      rand = Randomizer.randomizer(8)
      if String.starts_with?(input, ["http://", "https://"]) do
        {:ok, content} = Req.request(method: :get, url: input)
        content.body
        |> WorkflowDsl.JsonExprParser.process(:stream)
        |> WorkflowDsl.Interpreter.process(rand, subworkflow_name, args_body)
      else
        input
        |> WorkflowDsl.JsonExprParser.process(:file)
        |> WorkflowDsl.Interpreter.process(rand, subworkflow_name, args_body)
      end
      rand
    end

    defp clear_session(name) do
      Enum.map(WorkflowDsl.Storages.list_functions_by(%{"session" => name}), fn f ->
        WorkflowDsl.Storages.delete_function(f)
      end)
      Enum.map(WorkflowDsl.Storages.list_vars_by(%{"session" => name}), fn v ->
        WorkflowDsl.Storages.delete_var(v)
      end)
    end
  end
end
