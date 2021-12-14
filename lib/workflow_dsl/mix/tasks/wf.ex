defmodule Mix.Tasks.Wf do
  @shortdoc "Running the workflow"

  use Mix.Task

  alias WorkflowDsl.Utils.Randomizer

  defmodule Run do
    @impl Mix.Task
    def run(args) do
      parsed_args = OptionParser.parse(args, switches: [verbose: :boolean])
      case parsed_args do
        {is_verbose, [input], _} ->
          {_, verbose} = if length(is_verbose) > 0, do: Enum.at(is_verbose, 0), else: {true, false}
          if verbose, do: Logger.configure(level: :debug), else: Logger.configure(level: :info)
          {:ok, _} = Application.ensure_all_started(:workflow_dsl)
          rand = Randomizer.randomizer(8)
          if String.starts_with?(input, ["http://", "https://"]) do
            {:ok, content} = Req.request(:get, input)
            content.body
            |> WorkflowDsl.JsonExprParser.process(:stream)
            |> WorkflowDsl.Interpreter.process(rand)
          else
            input
            |> WorkflowDsl.JsonExprParser.process(:file)
            |> WorkflowDsl.Interpreter.process(rand)
          end

          IO.puts "\n#{input} is executed"
        _ ->
          IO.puts "\nCommand: mix wf.run <json workflow file path / URL> [--verbose]"
      end

    end
  end
end
