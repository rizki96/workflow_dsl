defmodule WorkflowDsl.CommandExecutor do

  alias WorkflowDsl.LoopExprParser
  alias WorkflowDsl.MathExprParser
  alias WorkflowDsl.CondExprParser
  alias WorkflowDsl.ListMapExprParser
  alias WorkflowDsl.Storages
  alias WorkflowDsl.JsonExprParser
  alias WorkflowDsl.Interpreter
  alias WorkflowDsl.Lang

  require Logger

  @halt_exec ["break", "end"]

  def execute_for_in(session, init_val, input, steps, index \\ "index") do
    #Logger.log(:debug, "input: #{inspect input}, init_val: #{inspect init_val}, steps: #{inspect steps}, index: #{inspect index}")
    {:ok, result, _, _, _, _} = LoopExprParser.parse_for_in(input)
    Enum.map(result, fn res ->
      Lang.eval(session, res)
      |> Enum.with_index()
      |> Enum.map(fn {it, idx} ->
        keep_value_process_steps(session, init_val, index, idx, it, steps)
      end)
    end)
  end

  def execute_for_range(session, init_val, input, steps, index \\ "index") do
    [min, max] = input
    #Logger.log(:debug, "input min: #{inspect min}, input max: #{inspect max}, init_val: #{inspect init_val}, steps: #{inspect steps}, index: #{inspect index}")
    {range, frac, precision} =
    cond do
      is_binary(min) and is_binary(max) ->
        {:ok, [res_min], _, _, _, _} = MathExprParser.parse_math(min)
        {:ok, [res_max], _, _, _, _} = MathExprParser.parse_math(max)

        {reach_min, frac_min} = reach_to_integer(Lang.eval(session, res_min))
        {reach_max, frac_max} = reach_to_integer(Lang.eval(session, res_max))

        create_range(reach_min, frac_min, reach_max, frac_max)
      true ->
        {reach_min, frac_min} = reach_to_integer(min)
        {reach_max, frac_max} = reach_to_integer(max)

        create_range(reach_min, frac_min, reach_max, frac_max)
    end
    #Logger.log(:debug, "create_range: #{inspect range} #{inspect frac}")

    Enum.with_index(range)
    |> Enum.each(fn {it, idx} ->
      it = if precision > 0, do: Float.round(it * frac, precision), else: it * frac
      keep_value_process_steps(session, init_val, index, idx, it, steps)
    end)
  end

  defp keep_value_process_steps(session, initval, idxname, idxval, number, steps) do
    case Storages.get_var_by(%{"session" => session, "name" => idxname}) do
      nil -> Storages.create_var(%{"session" => session, "name" => idxname, "value" => :erlang.term_to_binary(idxval)})
      var -> Storages.update_var(var, %{"value" => :erlang.term_to_binary(idxval)})
    end

    case Storages.get_var_by(%{"session" => session, "name" => initval}) do
      nil -> Storages.create_var(%{"session" => session, "name" => initval, "value" => :erlang.term_to_binary(number)})
      var -> Storages.update_var(var, %{"value" => :erlang.term_to_binary(number)})
    end

    steps
    |> JsonExprParser.convert2tuple()
    |> Interpreter.process(session)
  end

  defp create_range(reach_min, frac_min, reach_max, frac_max) do
    if frac_min > 0 or frac_max > 0 do
      create_range_frac(reach_min, frac_min, reach_max, frac_max)
    else
      {Range.new(reach_min, reach_max), 1, 0}
    end
  end

  defp create_range_frac(reach_min, frac_min, reach_max, frac_max) do
    {reach_min, reach_max} =
      cond do
        frac_min > frac_max ->
          {reach_min, reach_max * Float.pow(10.0, (frac_min - frac_max))}
        frac_max > frac_min ->
          {reach_min * Float.pow(10.0, (frac_max - frac_min)), reach_max}
        true ->
          {reach_min, reach_max}
      end
    precision = trunc(max(frac_min, frac_max))
    frac = if frac_min == 0.0 and frac_max == 0.0, do: 1, else: Float.round(Float.pow(0.1, precision), precision)

    {Range.new(trunc(reach_min), trunc(reach_max)), frac, precision}
  end

  defp reach_to_integer(orig_val, frac \\ 0) do
    if is_float(orig_val) do
      str_val = Float.to_string(orig_val)
      case String.split(str_val, ".") do
        [_, chk_val] ->
          if chk_val != "0", do: reach_to_integer(orig_val*10.0, frac + 1.0), else: {orig_val, frac}
        _ ->
          {orig_val, frac}
      end
    else
      {orig_val, frac}
    end
  end

  def execute_assign(session, valname, val) do
    result =
    if is_binary(val) and String.starts_with?(val, "${") do
      {:ok, [res], _, _, _, _} = MathExprParser.parse_math(val)
      #Logger.log(:debug, "#{inspect res}")
      Lang.eval(session, res)
    else
      val
    end

    # handle the mutable vars storage
    {:ok, names, _, _, _, _} = ListMapExprParser.parse_list_map(valname)
    #Logger.log(:debug, "I - valname: #{inspect valname}, names: #{inspect names}, result: #{inspect result}")
    result =
    cond do
      Kernel.length(names) == 1 ->
        case Storages.get_var_by(%{"session" => session, "name" => valname}) do
          nil ->
            Storages.create_var(%{"session" => session, "name" => valname, "value" => :erlang.term_to_binary(result), "typ" => ""})
            result
          varvalue ->
            Storages.update_var(varvalue, %{"value" => :erlang.term_to_binary(result)})
            result
        end
      true ->
        # construct the key and the values, for handling complex keys
        Enum.reduce(names, [], fn it, acc ->
          #Logger.log(:debug, "II - it: #{inspect it}, acc: #{inspect acc}")

          name = case it do
            {:vars, n} -> Enum.join(n)
            other -> Lang.eval(session, other)
          end

          case acc do
            [] ->
              case Lang.eval(session, it) do
                nil ->
                  Storages.create_var(%{"session" => session, "name" => name, "value" => :erlang.term_to_binary(nil), "typ" => ""})
                  [{:name, name}, {:values, nil}]
                varvalue ->
                  [{:name, name}, {:values, varvalue}]
              end
            other ->
              cond do
                is_nil(other[:values]) ->
                  if not is_nil(name) do
                    {:name, varname} = Enum.at(acc, 0)
                    varvalue = Storages.get_var_by(%{"session" => session, "name" => varname})
                    Storages.update_var(varvalue, %{"value" => :erlang.term_to_binary([[name, result]])})
                    other ++ [{:values, [[name, result]]}]
                  end
                is_list(other[:values]) ->
                  if not is_nil(name) do
                    #Logger.log(:debug, "acc: #{inspect acc}")
                    {:name, varname} = Enum.at(acc, 0)
                    varvalue = Storages.get_var_by(%{"session" => session, "name" => varname})
                    vals = Enum.filter(other[:values], fn [k,_] -> k != name end)
                    Storages.update_var(varvalue, %{"value" => :erlang.term_to_binary(vals ++ [[name, result]])})
                    other ++ [{:values, vals ++ [[name, result]]}]
                  end
                true ->
                  if not is_nil(name) do
                    {:name, varname} = Enum.at(acc, 0)
                    varvalue = Storages.get_var_by(%{"session" => session, "name" => varname})
                    vals = Enum.filter(Lang.eval(session, it), fn [k,_] -> k != name end)
                    Storages.update_var(varvalue, %{"value" => :erlang.term_to_binary(vals ++ [[name, result]])})
                    other ++ [{:values, vals ++ [[name, result]]}]
                  end
              end
          end
        end)
    end
    Logger.log(:debug, "valname: #{inspect valname}, value: #{inspect result}")
  end

  def execute_return(session, uid, val) do
    val =
    if is_binary(val) and String.starts_with?(val, "${") do
      {:ok, [res], _, _, _, _} = MathExprParser.parse_math(val)
      #Logger.log(:debug, "#{inspect res}")
      eval_res = Lang.eval(session, res)
      #Logger.log(:debug, "#{inspect eval_res}")
      eval_res
    else
      cond do
        is_list(val) ->
          l =
          Enum.map(val, fn v ->
            case v do
              [var, res] ->
                if is_binary(res) and String.starts_with?(res, "${") do
                  {:ok, [res], _, _, _, _} = MathExprParser.parse_math(res)
                  eval_res = Lang.eval(session, res)
                  {var, eval_res}
                else
                  {var, res}
                end
              var ->
                if is_binary(var) and String.starts_with?(var, "${") do
                  {:ok, [res], _, _, _, _} = MathExprParser.parse_math(var)
                  eval_res = Lang.eval(session, res)
                  eval_res
                else
                  var
                end
            end
          end)
          case Enum.at(l, 0) do
            {_, _} -> Enum.into(l, %{})
            _ -> l
          end
        true -> val
      end
    end

    if Storages.count_next_execs(%{"session" => session}) > 0 do
      case Storages.get_oldest_next_exec(%{"session" => session, "is_executed" => false}) do
        nil -> nil
        oldest ->
          if oldest.uid == uid do
            timestamp = :os.system_time(:microsecond)
            # execute_return will mark all uid as executed, once it is found the match
            all_next = Storages.list_next_execs(%{"session" => session})
            Enum.map(all_next, fn it ->
              Storages.update_next_exec(it, %{
                "is_executed" => true,
                "updated_at" => timestamp})
            end)
            val
          end
      end
    else
      val
    end
  end

  def maybe_execute_function(session, uid) do
    if (func = Storages.get_function_by(%{"session" => session, "uid" => uid})) != nil do
      if Storages.count_next_execs(%{"session" => session}) > 0 do
        case Storages.get_oldest_next_exec(%{"session" => session, "is_executed" => false}) do
          nil ->
            #Logger.log(:debug, "maybe_execute_function: session: #{inspect session}, uid: #{inspect uid}, oldest nil, #{inspect func}")
            if not is_nil(func.name) and not is_nil(func.args) do
              result = apply(:erlang.binary_to_term(func.module), :erlang.binary_to_term(func.name), [:erlang.binary_to_term(func.args)])
              Storages.update_function(func, %{"result" => :erlang.term_to_binary(result), "executed_at" => :os.system_time(:microsecond)})
            end
          oldest ->
            #Logger.log(:debug, "maybe_execute_function: session: #{inspect session}, uid: #{inspect uid}, #{inspect oldest}, #{inspect func}")
            if not is_nil(func.name) and not is_nil(func.args) and is_nil(func.executed_at)
              and oldest.uid == func.uid do
              result = apply(:erlang.binary_to_term(func.module), :erlang.binary_to_term(func.name), [:erlang.binary_to_term(func.args)])
              Storages.update_function(func, %{"result" => :erlang.term_to_binary(result), "executed_at" => :os.system_time(:microsecond)})
              is_executed = case result do
                {:ok, _} -> true
                {:error, _} -> true
                _ -> false
              end

              if (next = Storages.get_next_exec_by(%{"session" => session, "uid" => oldest.uid})) != nil do
                  timestamp = :os.system_time(:microsecond)
                  Storages.update_next_exec(next, %{
                    "is_executed" => is_executed,
                    "updated_at" => timestamp})
              end
            end
        end
      else
        #Logger.log(:debug, "maybe_execute_function: No next command, session: #{inspect session}, uid: #{inspect uid}, ")
        if not is_nil(func.name) and not is_nil(func.args) do
          result = apply(:erlang.binary_to_term(func.module), :erlang.binary_to_term(func.name), [:erlang.binary_to_term(func.args)])
          Storages.update_function(func, %{"result" => :erlang.term_to_binary(result), "executed_at" => :os.system_time(:microsecond)})
        end
      end
    end
  end

  def execute_next(session, uid, params) do
    if (exec = Storages.get_next_exec_by(%{"session" => session, "uid" => uid})) != nil do
      timestamp = :os.system_time(:microsecond)
      inserted_at = if is_nil(exec.inserted_at), do: timestamp, else: exec.inserted_at

      Storages.update_next_exec(exec, %{
        "next_uid" => params,
        "inserted_at" => inserted_at,
        "updated_at" => timestamp,
      })
    end

    case Storages.get_oldest_next_exec(%{"session" => session, "is_executed" => false}) do
      nil -> # nil
        #Logger.log(:debug, "execute_next: next_exec nil, params: #{inspect params}")
        maybe_execute_function(session, params)
        maybe_execute_next(session, params)
      oldest ->
        #Logger.log(:debug, "execute_next: oldest next_exec exists: #{inspect oldest.uid}, params: #{inspect params}")
        uid = if params in @halt_exec or is_nil(oldest.triggered_script), do: params, else: oldest.uid
        maybe_execute_function(session, uid)
        maybe_execute_next(session, uid)
    end
  end

  defp maybe_execute_next(session, uid) do
    if Storages.get_function_by(%{"session" => session, "uid" => uid}) == nil do
      case Storages.get_next_exec_by(%{"session" => session, "uid" => uid}) do
        nil -> nil
        next_exec ->
          #Logger.log(:debug, "maybe_execute_next, next_exec: #{inspect next_exec}")
          if next_exec.is_executed == false and not is_nil(next_exec.triggered_script) do
            timestamp = :os.system_time(:microsecond)
            Storages.update_next_exec(next_exec, %{"is_executed" => true, "updated_at" => timestamp})
            if not is_nil(next_exec.next_uid) do
              if (next = Storages.get_next_exec_by(%{"session" => session, "uid" => next_exec.next_uid})) != nil do
                if not is_nil(next.triggered_script) do
                  #Logger.log(:debug, "maybe_execute_next, next: #{inspect :erlang.binary_to_term(next.triggered_script)}")
                  Interpreter.exec_command(session, next.uid, :erlang.binary_to_term(next.triggered_script))
                end
              end
            end
          else
            if not is_nil(next_exec.triggered_script) do
              #Logger.log(:debug, "maybe_execute_next, next_exec: #{inspect :erlang.binary_to_term(next_exec.triggered_script)}")
              Interpreter.exec_command(session, uid, :erlang.binary_to_term(next_exec.triggered_script))
            end
          end
      end
    end
  end

  def execute_result(session, uid, params) do
    case Storages.get_function_by(%{"session" => session, "uid" => uid}) do
      nil -> nil
      func ->
        result =
        case :erlang.binary_to_term(func.result) do
          {:ok, res} ->
            if is_struct(res), do: Map.from_struct(res), else: res
          {:error, err} ->
            if is_struct(err), do: Map.from_struct(err), else: err
          res ->
            if is_struct(res), do: Map.from_struct(res), else: res
        end
        execute_assign(session, params, result)
    end
  end

  def execute_switch(session, uid, params) do
    case params do
      {:next, true, nxt} ->
        #Logger.log(:debug, "execute_switch session: #{inspect session}, uid: #{inspect nxt}")
        if nxt not in @halt_exec and is_nil(Storages.get_next_exec_by(%{"session" => session, "uid" => nxt})) do
          timestamp = :os.system_time(:microsecond)
          Storages.create_next_exec(%{
            "session" => session,
            "uid" => nxt,
            "next_uid" => nil,
            "is_executed" => false,
            "inserted_at" => timestamp,
            "updated_at" => timestamp
          })
        end
        execute_next(session, uid, nxt)
      {:result, true, rst} ->
        execute_result(session, uid, rst)
      {:steps, true, stp} ->
        stp
        |> JsonExprParser.convert2tuple()
        |> Interpreter.process(session)
      _ -> nil
    end
  end

  def execute_condition(session, _uid, params) do
    {:ok, [result], _, _, _, _} = CondExprParser.parse_cond(params)
    #Logger.log(:debug, "#{inspect result}")
    eval_res = Lang.eval(session, result)
    #Logger.log(:debug, "#{inspect eval_res}")
    eval_res
  end
end
