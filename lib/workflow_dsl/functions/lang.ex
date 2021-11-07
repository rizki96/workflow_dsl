defmodule WorkflowDsl.Lang do

  alias WorkflowDsl.Storages

  #require Logger

  # eval for math
  def eval(session, {:mul, [val0, val1]}), do: eval(session, val0) * eval(session, val1)
  def eval(session, {:div, [val0, val1]}), do: eval(session, val0) / eval(session, val1)
  def eval(session, {:sub, [val0, val1]}), do: eval(session, val0) - eval(session, val1)
  def eval(session, {:rem, [val0, val1]}), do: rem(eval(session, val0), eval(session, val1))
  def eval(session, {:flr, [val0, val1]}), do: floor(eval(session, val0) / eval(session, val1))
  def eval(session, {:vars, [val0, val1]}) do
    # TODO: complete the condition below
    cond do
      String.contains?(val1, "[") and String.contains?(val1, "]") ->
        container = eval(session, {:vars, [val0]})
        idx = String.replace(val1, ["[", "]"], "")
        if length(Enum.at(container, 0)) == 2 do
          # map
          index = eval(session, {:vars, [idx]})
          map = Enum.into(container, %{}, fn [k, v] -> {k, v} end)
          map[index]
        else
          # list
          container[String.to_integer(idx)]
        end
      String.contains?(val1, ".") ->
        container = eval(session, {:vars, [val0]})
        if is_map(container) do
          keys = String.split(val1, ".")
          result =
          keys
          |> Enum.filter(fn it -> it != "" end)
          |> Enum.reduce(nil, fn k, acc ->
            case acc do
              nil ->
                k = if not Map.has_key?(container, k), do: String.to_atom(k), else: k
                container[k]
              other ->
                k = if not Map.has_key?(other, k), do: String.to_atom(k), else: k
                other[k]
              end
          end)
          result
        else
          container
        end
      true ->
        eval(session, {:vars, [val0 <> val1]})
    end
  end
  def eval(session, {:add, [val0, val1]}) do
    eval0 = eval(session, val0)
    eval1 = eval(session, val1)
    if is_binary(eval0) and is_binary(eval1), do: eval0 <> eval1, else: eval0 + eval1
  end
  def eval(_session, {:int, [val]}), do: val
  def eval(session, {:int, [_, var]}) do
    val = eval(session, var)
    if is_binary(val), do: String.to_integer(val), else: val
  end
  def eval(_session, {:double, [val]}), do: String.to_float(val)
  def eval(session, {:double, ["double", var]}) do
    val = eval(session, var)
    if is_binary(val), do: String.to_float(val), else: val
  end
  def eval(_session, {:str, [val]}), do: to_string(val)
  def eval(session, {:str, ["string", var]}) do
    val = eval(session, var)
    if is_binary(val), do: val, else: to_string(val)
  end
  def eval(_session, {:bool, [val]}), do: String.to_existing_atom(String.downcase(val))
  def eval(session, {:vars, [val]}) do
    var = Storages.get_var_by(%{"session" => session, "name" => val})
    :erlang.binary_to_term(var.value)
  end
  def eval(session, {:neg_vars, [val]}) do
    -eval(session, val)
  end

  # implement eval for cond
  def eval(session, {:eq, [val0, val1]}) do
    eval(session, val0) == eval(session, val1)
  end
  def eval(session, {:neq, [val0, val1]}) do
    eval(session, val0) != eval(session, val1)
  end
  def eval(session, {:or, [val0, val1]}) do
    eval(session, val0) or eval(session, val1)
  end
  def eval(session, {:and, [val0, val1]}) do
    eval(session, val0) and eval(session, val1)
  end
  def eval(session, {:gt, [val0, val1]}) do
    eval(session, val0) > eval(session, val1)
  end
  def eval(session, {:gte, [val0, val1]}) do
    eval(session, val0) >= eval(session, val1)
  end
  def eval(session, {:lt, [val0, val1]}) do
    eval(session, val0) < eval(session, val1)
  end
  def eval(session, {:lte, [val0, val1]}) do
    eval(session, val0) <= eval(session, val1)
  end

end
