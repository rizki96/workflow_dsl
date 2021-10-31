defmodule WorkflowDsl.JsonExprParser do

  require Logger

  def process(input, input_type) do
    {input_type, input}
    |> read()
    |> convert2tuple()
  end

  def convert2tuple(input) do
    input
    |> Enum.with_index()
    |> Enum.map(fn {res, idx} ->
      {idx, Enum.flat_map(res, fn r ->
        cond do
          is_bitstring(r) -> [r]
          true -> r
        end
      end)
      |> List.to_tuple()}
    end)
  end

  defp read({:stream, input}) do
    result =
      input |> WorkflowDsl.Utils.StringKeyword.decode!()

    iterate(result)
  end

  defp read({:file, input}) do
    stream = File.read!(input)
    read({:stream, stream})
  end

  defp iterate(result) do
    cond do
      is_struct(result, WorkflowDsl.Utils.StringKeyword) ->
        iterate(result.data)
      is_list(result) ->
        Enum.map(result, fn res -> iterate(res) end)
      is_tuple(result) ->
        Enum.map(Tuple.to_list(result), fn res -> iterate(res) end)
      true -> result
    end
  end

end
