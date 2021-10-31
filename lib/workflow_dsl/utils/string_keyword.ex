defmodule WorkflowDsl.Utils.StringKeyword do
  defstruct data: []

  @spec decode!(binary) :: any
  def decode!(string) when is_bitstring(string) do
    Process.put(:key_count, 0)

    string
    |> Jason.decode!(
      keys: fn key ->
        count = Process.get(:key_count)
        Process.put(:key_count, count + 1)
        {count, key}
      end
    )
    |> new()
  end

  defp new(conf) when is_map(conf) do
    data =
      conf
      |> Map.to_list()
      |> Enum.sort_by(fn {{idx, _}, _} -> idx end)
      |> Enum.map(fn {{_, k}, v} -> {k, new(v)} end)

    %__MODULE__{data: data}
  end

  defp new(list) when is_list(list), do: Enum.map(list, &new/1)

  defp new(value), do: value
end

defimpl Jason.Encoder, for: StringKeyword do
  def encode(%{data: value}, opts), do: Jason.Encode.keyword(value, opts)
end
