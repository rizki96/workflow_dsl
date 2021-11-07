defmodule WorkflowDsl.Interpreter do

  require Logger

  alias WorkflowDsl.CommandExecutor

  @default_module_prefix "Elixir.WorkflowDsl"

  def process(input, session) when is_list(input) do
    # generate session
    Enum.map(input, fn {_, code} ->
      convert2key(code)
    end)
    |> execute(session)
  end

  def process(_input, _session) do

  end

  defp execute(code, session) do
    Enum.map(code, fn {k, v} ->
      Enum.map(v, fn p ->
        command(session, k, p)
      end)
    end)
  end

  defp convert2key(code) do
    case code do
      {k, [input_key, params]} when is_bitstring(input_key) -> {String.to_atom(k), [to_keyword([input_key, params])]}
      {k, [input_key1, params1], [input_key2, params2]} when is_bitstring(input_key1) and is_bitstring(input_key2) ->
        {String.to_atom(k), [to_keyword([input_key1, params1]), to_keyword([input_key2, params2])]}
      {k, v} ->
        cond do
          is_list(v) -> {k, Enum.map(v, fn cmd -> to_keyword(cmd) end)}
          true -> {k, to_keyword(v)}
        end
      _ -> Logger.log(:debug, "#{inspect code}")
        code
    end
  end

  defp to_keyword(["assign", params]), do: {:assign, params}
  defp to_keyword(["for", params]), do: {:for, params}
  defp to_keyword(["return", params]), do: {:return, params}
  defp to_keyword(["call", params]), do: {:call, params}
  defp to_keyword(["args", params]), do: {:args, params}
  defp to_keyword(["next", params]), do: {:next, params}
  defp to_keyword(["result", params]), do: {:result, params}
  defp to_keyword(["switch", params]), do: {:switch, params}
  defp to_keyword(["steps", params]), do: {:steps, params}
  defp to_keyword(["params", params]), do: {:params, params}
  defp to_keyword([func, params]), do: {:unknown, [func, params]}

  defp command(session, uid, {:assign, params}) do
    # holds the params value to ets
    Enum.map(params, fn [[varname, val]] ->
      CommandExecutor.execute_assign(session, varname, val)
    end)

    Logger.log(:debug, "assign: #{inspect params}, session: #{inspect session}, uid: #{inspect uid}")
  end

  defp command(session, uid, {:for, params}) do
    {varname, inval, idxvar, stepvar} =
    case params do
      [val, inval, index, steps] ->
        ["value", varname] = val
        [["index", idxvar]] = index
        ["steps", stepvar] = steps

        {varname, inval, idxvar, stepvar}

      [val, inval, steps] ->
        ["value", varname] = val
        ["steps", stepvar] = steps

        {varname, inval, "index", stepvar}
    end

    case inval do
      ["in", invar] ->
        CommandExecutor.execute_for_in(session, varname, invar, stepvar, idxvar)
      ["range", rangevar] ->
        CommandExecutor.execute_for_range(session, varname, rangevar, stepvar, idxvar)
    end

    Logger.log(:debug, "for: #{inspect params}, session: #{inspect session}, uid: #{inspect uid}")
  end

  defp command(session, uid, {:return, params}) do
    case CommandExecutor.execute_return(session, uid, params) do
      nil -> nil
      output -> Logger.log(:debug, "return: #{inspect params} #{inspect output}, session: #{inspect session}, uid: #{inspect uid}")
    end
  end

  defp command(session, uid, {:call, params}) do
    modfunc = String.split(String.capitalize(params), ".")
    module_name = String.to_existing_atom("#{@default_module_prefix}.#{Enum.at(modfunc,0)}")
    CommandExecutor.try_execute_function(session, uid, module_name, String.to_atom(Enum.at(modfunc, 1)), nil)
    Logger.log(:debug, "call: #{inspect params}, session: #{inspect session}, uid: #{uid}")
  end

  defp command(session, uid, {:args, params}) do
    CommandExecutor.try_execute_function(session, uid, nil, nil, params)
    Logger.log(:debug, "args: #{inspect params}, session: #{inspect session}, uid: #{uid}")
  end

  defp command(session, uid, {:next, params}) do
    CommandExecutor.execute_next(session, uid, params)
    Logger.log(:debug, "next: #{inspect params}, session: #{inspect session}, uid: #{uid}")
  end

  defp command(session, uid, {:result, params}) do
    # assign the result to var table
    CommandExecutor.execute_result(session, uid, params)
    Logger.log(:debug, "result: #{inspect params}, session: #{inspect session}, uid: #{uid}")
  end

  defp command(session, uid, {:switch, params}) do
    # TODO: - case for condition -> next
    # TODO: - case for condition -> return
    # TODO: - case for condition -> steps
    result =
    Enum.map(params, fn it ->
      case it do
        [["condition", cnd], ["next", nxt]] ->
          {:next, CommandExecutor.execute_condition(session, uid, cnd), nxt}
        [["condition", cnd], ["return", ret]] ->
          {:return, CommandExecutor.execute_condition(session, uid, cnd), ret}
        [["condition", cnd], ["steps", stp]] ->
          {:steps, CommandExecutor.execute_condition(session, uid, cnd), stp}
        _ -> nil
      end
    end)
    |> Enum.filter(fn {_, cnd, _} -> cnd == true end)

    case CommandExecutor.execute_switch(session, uid, Enum.at(result,0)) do
      nil -> nil
      res ->
        Logger.log(:debug, "switch: #{inspect params}, session: #{inspect session}, uid: #{uid}, result: #{inspect res}")
    end
    #{_, next} =
    #Enum.filter(conditions, fn {c, _next} ->
    #  c == true
    #end)
    #|> Enum.at(0)
    #command(session, uid, {:next, next})
  end

  defp command(session, uid, input) do
    Logger.log(:debug, "unknown command, session: #{inspect session}, uid: #{inspect uid}, input: #{inspect input}")
  end
end
