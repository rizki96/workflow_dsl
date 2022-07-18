defmodule WorkflowDsl.CommandExecutor do
  alias WorkflowDsl.LoopExprParser
  alias WorkflowDsl.MathExprParser
  alias WorkflowDsl.CondExprParser
  alias WorkflowDsl.ListMapExprParser
  alias WorkflowDsl.Storages
  alias WorkflowDsl.Storages.DelayedExec
  alias WorkflowDsl.JsonExprParser
  alias WorkflowDsl.Interpreter
  alias WorkflowDsl.Lang

  require Logger

  def execute_for_in(session, init_val, input, steps, index \\ "index") do
    # Logger.log(:debug, "input: #{inspect input}, init_val: #{inspect init_val}, steps: #{inspect steps}, index: #{inspect index}")
    {:ok, result, _, _, _, _} = LoopExprParser.parse_for_in(input)

    Enum.map(result, fn res ->
      Lang.eval(session, res)
      |> Enum.with_index()
      |> Enum.map(fn {it, idx} ->
        keep_session_value(session, init_val, index, idx, it)
        execute_steps(session, steps)
      end)
    end)
  end

  def execute_for_range(session, init_val, input, steps, index \\ "index") do
    [min, max] = input

    # Logger.log(:debug, "input min: #{inspect min}, input max: #{inspect max}, init_val: #{inspect init_val}, steps: #{inspect steps}, index: #{inspect index}")
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

    # Logger.log(:debug, "create_range: #{inspect range} #{inspect frac}")

    Enum.with_index(range)
    |> Enum.each(fn {it, idx} ->
      it = if precision > 0, do: Float.round(it * frac, precision), else: it * frac
      keep_session_value(session, init_val, index, idx, it)
      execute_steps(session, steps)
    end)
  end

  defp keep_session_value(session, initval, idxname, idxval, number) do
    case Storages.get_var_by(%{"session" => session, "name" => idxname}) do
      nil ->
        Storages.create_var(%{
          "session" => session,
          "name" => idxname,
          "value" => :erlang.term_to_binary(idxval)
        })

      var ->
        Storages.update_var(var, %{"value" => :erlang.term_to_binary(idxval)})
    end

    case Storages.get_var_by(%{"session" => session, "name" => initval}) do
      nil ->
        Storages.create_var(%{
          "session" => session,
          "name" => initval,
          "value" => :erlang.term_to_binary(number)
        })

      var ->
        Storages.update_var(var, %{"value" => :erlang.term_to_binary(number)})
    end
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
          {reach_min, reach_max * Float.pow(10.0, frac_min - frac_max)}

        frac_max > frac_min ->
          {reach_min * Float.pow(10.0, frac_max - frac_min), reach_max}

        true ->
          {reach_min, reach_max}
      end

    precision = trunc(max(frac_min, frac_max))

    frac =
      if frac_min == 0.0 and frac_max == 0.0,
        do: 1,
        else: Float.round(Float.pow(0.1, precision), precision)

    {Range.new(trunc(reach_min), trunc(reach_max)), frac, precision}
  end

  defp reach_to_integer(orig_val, frac \\ 0) do
    if is_float(orig_val) do
      str_val = Float.to_string(orig_val)

      case String.split(str_val, ".") do
        [_, chk_val] ->
          if chk_val != "0",
            do: reach_to_integer(orig_val * 10.0, frac + 1.0),
            else: {orig_val, frac}

        _ ->
          {orig_val, frac}
      end
    else
      {orig_val, frac}
    end
  end

  def execute_steps(session, steps, parent_uid) do
    steps
    |> JsonExprParser.convert2tuple()
    |> Interpreter.process(session, parent_uid)
  end

  def execute_steps(session, steps) do
    steps
    |> JsonExprParser.convert2tuple()
    |> Interpreter.process(session)
  end

  def execute_assign(session, valname, val) do
    result = Lang.eval(session, val)

    # handle the mutable vars storage
    {:ok, names, _, _, _, _} = ListMapExprParser.parse_list_map(valname)

    # Logger.log(:debug, "I - valname: #{inspect valname}, names: #{inspect names}, result: #{inspect result}")
    result =
      cond do
        Kernel.length(names) == 1 ->
          case Storages.get_var_by(%{"session" => session, "name" => valname}) do
            nil ->
              Storages.create_var(%{
                "session" => session,
                "name" => valname,
                "value" => :erlang.term_to_binary(result),
                "typ" => ""
              })

              result

            varvalue ->
              Storages.update_var(varvalue, %{"value" => :erlang.term_to_binary(result)})
              result
          end

        true ->
          # construct the key and the values, for handling complex keys
          Enum.reduce(names, [], fn it, acc ->
            # Logger.log(:debug, "II - it: #{inspect it}, acc: #{inspect acc}")

            name =
              case it do
                {:vars, n} -> Enum.join(n)
                other -> Lang.eval(session, other)
              end

            case acc do
              [] ->
                case Lang.eval(session, it) do
                  nil ->
                    Storages.create_var(%{
                      "session" => session,
                      "name" => name,
                      "value" => :erlang.term_to_binary(nil),
                      "typ" => ""
                    })

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

                      Storages.update_var(varvalue, %{
                        "value" => :erlang.term_to_binary([[name, result]])
                      })

                      other ++ [{:values, [[name, result]]}]
                    end

                  is_list(other[:values]) ->
                    if not is_nil(name) do
                      # Logger.log(:debug, "acc: #{inspect acc}")
                      {:name, varname} = Enum.at(acc, 0)
                      varvalue = Storages.get_var_by(%{"session" => session, "name" => varname})
                      vals = Enum.filter(other[:values], fn [k, _] -> k != name end)

                      Storages.update_var(varvalue, %{
                        "value" => :erlang.term_to_binary(vals ++ [[name, result]])
                      })

                      other ++ [{:values, vals ++ [[name, result]]}]
                    end

                  true ->
                    if not is_nil(name) do
                      {:name, varname} = Enum.at(acc, 0)
                      varvalue = Storages.get_var_by(%{"session" => session, "name" => varname})
                      vals = Enum.filter(Lang.eval(session, it), fn [k, _] -> k != name end)

                      Storages.update_var(varvalue, %{
                        "value" => :erlang.term_to_binary(vals ++ [[name, result]])
                      })

                      other ++ [{:values, vals ++ [[name, result]]}]
                    end
                end
            end
          end)
      end

    Logger.log(:debug, "valname: #{inspect(valname)}, value: #{inspect(result)}")
  end

  def execute_return(session, uid, val) do
    val =
      if is_binary(val) do
        Lang.eval(session, val)
      else
        cond do
          is_list(val) ->
            l =
              Enum.map(val, fn v ->
                case v do
                  [var, res] ->
                    {var, Lang.eval(session, res)}

                  var ->
                    Lang.eval(session, var)
                end
              end)

            case Enum.at(l, 0) do
              {_, _} -> Enum.into(l, %{})
              _ -> l
            end

          true ->
            val
        end
      end

    current = Storages.get_next_exec_by(%{"session" => session, "uid" => uid})

    if current != nil and current.parent_uid != nil and current.parent_uid != "" do
      all_next =
        Storages.list_next_execs_by(%{"session" => session, "parent_uid" => current.parent_uid})

      Enum.map(all_next, fn it ->
        Storages.update_next_exec(it, %{
          "is_executed" => true
        })
      end)

      val
    else
      if Storages.get_oldest_next_exec(%{"session" => session, "is_executed" => false}) != nil do
        all_next = Storages.list_next_execs_by(%{"session" => session})

        Enum.map(all_next, fn it ->
          Storages.update_next_exec(it, %{
            "is_executed" => true
          })
        end)

        val
      end
    end
  end

  def execute_next(session, params) do
    if DelayedExec.value(session) == nil, do: DelayedExec.reset(session, params)
    # Logger.log(:debug, "#{inspect DelayedExec.value(session)}")
  end

  def execute_result(session, uid, params) do
    case Storages.get_function_by(%{"session" => session, "uid" => uid}) do
      nil ->
        nil

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
        # if nxt not in @halt_exec do
        execute_next(session, nxt)

      # end
      {:result, true, rst} ->
        execute_result(session, uid, rst)

      {:steps, true, stp} ->
        execute_steps(session, stp)

      _ ->
        nil
    end
  end

  def execute_condition(session, _uid, params) do
    {:ok, [result], _, _, _, _} = CondExprParser.parse_cond(params)
    # Logger.log(:debug, "#{inspect result}")
    eval_res = Lang.eval(session, result)
    # Logger.log(:debug, "#{inspect eval_res}")
    eval_res
  end
end
