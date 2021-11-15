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

  def execute_for_in(session, init_val, input, steps, index \\ "index") do
    #Logger.log(:debug, "input: #{inspect input}, init_val: #{inspect init_val}, steps: #{inspect steps}, index: #{inspect index}")
    {:ok, result, _, _, _, _} = LoopExprParser.parse_for_in(input)
    Enum.map(result, fn res ->
      case res do
        {:list, [func, {:vars, varnames}]} ->
          varname = Enum.join(varnames)
          localvar = Storages.get_var_by(%{"session" => session, "name" => varname})
          if localvar != nil do
            apply(__MODULE__, String.to_atom(func), [:erlang.binary_to_term(localvar.value)])
          else
            []
          end
        {:vars, varnames} ->
          varname = Enum.join(varnames)
          localvar = Storages.get_var_by(%{"session" => session, "name" => varname})
          :erlang.binary_to_term(localvar.value)
      end
      |> Enum.with_index()
      |> Enum.map(fn {it, idx} ->
        case Storages.get_var_by(%{"session" => session, "name" => index}) do
          nil -> Storages.create_var(%{"session" => session, "name" => index, "value" => :erlang.term_to_binary(idx)})
          var -> Storages.update_var(var, %{"value" => :erlang.term_to_binary(idx)})
        end

        case Storages.get_var_by(%{"session" => session, "name" => init_val}) do
          nil -> Storages.create_var(%{"session" => session, "name" => init_val, "value" => :erlang.term_to_binary(it)})
          var -> Storages.update_var(var, %{"value" => :erlang.term_to_binary(it)})
        end

        steps
        |> JsonExprParser.convert2tuple()
        |> Interpreter.process(session)
      end)
    end)
  end

  def execute_for_range(session, init_val, input, steps, index \\ "index") do
    [min, max] = input
    #Logger.log(:debug, "input min: #{inspect min}, input max: #{inspect max}, init_val: #{inspect init_val}, steps: #{inspect steps}, index: #{inspect index}")
    {range, frac} =
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

    Enum.with_index(range)
    |> Enum.each(fn {it, idx} ->
      number = it * frac
      case Storages.get_var_by(%{"session" => session, "name" => index}) do
        nil -> Storages.create_var(%{"session" => session, "name" => index, "value" => :erlang.term_to_binary(idx)})
        var -> Storages.update_var(var, %{"value" => :erlang.term_to_binary(idx)})
      end

      case Storages.get_var_by(%{"session" => session, "name" => init_val}) do
        nil -> Storages.create_var(%{"session" => session, "name" => init_val, "value" => :erlang.term_to_binary(number)})
        var -> Storages.update_var(var, %{"value" => :erlang.term_to_binary(number)})
      end

      steps
      |> JsonExprParser.convert2tuple()
      |> Interpreter.process(session)
    end)
  end

  defp create_range(reach_min, frac_min, reach_max, frac_max) do
    if frac_min > 0 or frac_max > 0 do
      create_range_frac(reach_min, frac_min, reach_max, frac_max)
    else
      {Range.new(reach_min, reach_max), 1}
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
    frac = if frac_min == 0.0 and frac_max == 0.0, do: 1.0, else: Float.pow(0.1, max(frac_min, frac_max))

    {Range.new(trunc(reach_min), trunc(reach_max)), frac}
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
      Lang.eval(session, res)
    else
      val
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

  #def execute_steps(session, steps) do
  #  steps
  #  |> JsonExprParser.convert2tuple()
  #  |> Interpreter.process(session)
  #end

  def try_execute_function(session, uid, module, name, args) do
    function =
    case Storages.get_function_by(%{"session" => session, "uid" => uid}) do
      nil -> cond do
        not is_nil(name) ->
          #Logger.log(:debug, "Create Module: #{inspect module} #{inspect name}")
          Storages.create_function(%{"session" => session, "uid" => uid, "module" => :erlang.term_to_binary(module), "name" => :erlang.term_to_binary(name)})
        not is_nil(args) ->
          args = Enum.map(args, fn arg ->
            case arg do
              [k, val] ->
                if String.starts_with?(val, "${") and String.ends_with?(val, "}") do
                  {:ok, [res], _, _, _, _} = MathExprParser.parse_math(val)
                  Lang.eval(session, res)
                else
                  [k, val]
                end
              other -> other
            end
          end)
          #Logger.log(:debug, "Create Args: #{inspect args}")
          Storages.create_function(%{"session" => session, "uid" => uid, "args" => :erlang.term_to_binary(args)})
        true -> {:error, nil}
      end
      func -> cond do
        not is_nil(name) and is_nil(func.name) ->
          #Logger.log(:debug, "Update Module: #{inspect module} #{inspect name}")
          Storages.update_function(func, %{"name" => :erlang.term_to_binary(name), "module" => :erlang.term_to_binary(module)})
        not is_nil(args) and is_nil(func.args) ->
          args = Enum.map(args, fn arg ->
            case arg do
              [k, val] ->
                if is_binary(val) and String.starts_with?(val, "${") do
                  {:ok, [res], _, _, _, _} = MathExprParser.parse_math(val)
                  [k, Lang.eval(session, res)]
                else
                  [k, val]
                end
              other -> other
            end
          end)
          #Logger.log(:debug, "Update Args: #{inspect args}")
          Storages.update_function(func, %{"args" => :erlang.term_to_binary(args)})
        true ->
          if not is_nil(func.executed_at), do: {:error, func}, else: {:ok, func}
      end
    end

    # TRACE: error after clear state
    case function do
      {:ok, func} ->
        if Storages.count_next_execs(%{"session" => session}) > 0 do
          case Storages.get_oldest_next_exec(%{"session" => session, "is_executed" => false}) do
            nil -> nil
            oldest ->
              #Logger.log(:debug, "try_execute_function: #{inspect oldest} #{inspect func}")
              if not is_nil(func.name) and not is_nil(func.args)
                and oldest.uid == func.uid do
                result = apply(:erlang.binary_to_term(func.module), :erlang.binary_to_term(func.name), [:erlang.binary_to_term(func.args)])
                Storages.update_function(func, %{"result" => :erlang.term_to_binary(result), "executed_at" => :os.system_time(:microsecond)})

                case Storages.get_next_exec_by(%{"session" => session, "uid" => oldest.uid}) do
                  nil ->
                    timestamp = :os.system_time(:microsecond)
                    #Logger.log(:debug, "create #{inspect func.uid}")
                    Storages.create_next_exec(%{
                      "session" => session,
                      "uid" => func.uid,
                      "is_executed" => true,
                      "inserted_at" => timestamp,
                      "updated_at" => timestamp})
                  next ->
                    timestamp = :os.system_time(:microsecond)
                    #Logger.log(:debug, "update #{inspect next.uid}")
                    Storages.update_next_exec(next, %{
                      "is_executed" => true,
                      "updated_at" => timestamp})
                end
              end
          end
        else
          #Logger.log(:debug, "No next_exec")
          if not is_nil(func.name) and not is_nil(func.args) do
            result = apply(:erlang.binary_to_term(func.module), :erlang.binary_to_term(func.name), [:erlang.binary_to_term(func.args)])
            Storages.update_function(func, %{"result" => :erlang.term_to_binary(result), "executed_at" => :os.system_time(:microsecond)})
            timestamp = :os.system_time(:microsecond)

            #Logger.log(:debug, "create #{inspect func.uid}")
            Storages.create_next_exec(%{
              "session" => session,
              "uid" => func.uid,
              "is_executed" => true,
              "inserted_at" => timestamp,
              "updated_at" => timestamp})
          end
        end
      {:error, _func} ->
        #Logger.log(:debug, "error: #{inspect func}")
        nil
    end
  end

  def execute_next(session, uid, params) do
    case Storages.get_next_exec_by(%{"session" => session, "uid" => uid}) do
      nil ->
        timestamp = :os.system_time(:microsecond)
        func = Storages.get_function_by(%{"session" => session, "uid" => uid})
        is_executed = if not is_nil(func), do: not is_nil(func.executed_at), else: false
        Storages.create_next_exec(%{"session" => session, "uid" => uid, "next_uid" => params, "is_executed" => is_executed,
          "inserted_at" => timestamp, "updated_at" => timestamp})
        if params != "end" and params != "break" do
          func = Storages.get_function_by(%{"session" => session, "uid" => params})
          is_executed = if not is_nil(func), do: not is_nil(func.executed_at), else: false
          case Storages.get_next_exec_by(%{"session" => session, "uid" => params}) do
            nil ->
              #Logger.log(:debug, "create #{inspect params}")
              Storages.create_next_exec(%{"session" => session, "uid" => params, "is_executed" => is_executed,
              "inserted_at" => timestamp, "updated_at" => timestamp})
            next_exec ->
              #Logger.log(:debug, "update #{inspect params}")
              Storages.update_next_exec(next_exec, %{"is_executed" => is_executed,
              "updated_at" => timestamp})
          end
        end
      next ->
        timestamp = :os.system_time(:microsecond)
        func = Storages.get_function_by(%{"session" => session, "uid" => uid})
        is_executed = if not is_nil(func), do: not is_nil(func.executed_at), else: false
        Storages.update_next_exec(next, %{"next_uid" => params, "is_executed" => is_executed,
          "updated_at" => timestamp})
        if params != "end" and params != "break" do
          func = Storages.get_function_by(%{"session" => session, "uid" => params})
          is_executed = if not is_nil(func), do: not is_nil(func.executed_at), else: false
          case Storages.get_next_exec_by(%{"session" => session, "uid" => params}) do
            nil ->
              #Logger.log(:debug, "create #{inspect params}")
              Storages.create_next_exec(%{"session" => session, "uid" => params, "is_executed" => is_executed,
              "inserted_at" => timestamp, "updated_at" => timestamp})
            next_exec ->
              #Logger.log(:debug, "update #{inspect params}")
              Storages.update_next_exec(next_exec, %{"is_executed" => is_executed,
              "updated_at" => timestamp})
          end
        end
    end

    case Storages.get_oldest_next_exec(%{"session" => session, "is_executed" => false}) do
      nil -> nil
      oldest ->
        #Logger.log(:debug, "execute_next: oldest Next_exec exists: #{inspect oldest}")
        try_execute_function(session, oldest.uid, nil, nil, nil)
        if not is_nil(oldest.next_uid) do
          case Storages.get_next_exec_by(%{"session" => session, "uid" => oldest.next_uid}) do
            nil -> nil
            oldest_next ->
              #Logger.log(:debug, "execute_next: oldest_next Next_exec exists: #{inspect oldest_next}")
              if not is_nil(oldest_next.next_uid), do:
                execute_next(session, oldest_next.uid, oldest_next.next_uid)
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
        timestamp = :os.system_time(:microsecond)
        Storages.create_next_exec(%{"session" => session, "uid" => nxt, "is_executed" => false,
        "inserted_at" => timestamp, "updated_at" => timestamp})
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
    Lang.eval(session, result)
  end

  def keys(map) do
    Enum.map(map, fn it ->
      cond do
        is_list(it) -> Enum.at(it, 0)
        true -> nil
      end
    end) |> Enum.filter(fn it -> it != nil end)
  end

  #def string(val) do
  #
  #end

  #def range(arr) do
  #
  #end
end
