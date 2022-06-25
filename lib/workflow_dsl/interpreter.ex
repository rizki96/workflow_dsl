defmodule WorkflowDsl.Interpreter do

  require Logger

  alias WorkflowDsl.CommandExecutor
  alias WorkflowDsl.Storages
  alias WorkflowDsl.Storages.DelayedExec
  #alias WorkflowDsl.Lang

  @default_module_prefix "Elixir.WorkflowDsl"
  @halt_exec ["continue", "break", "end"]

  def process(input, session, subname, subargs) when is_list(input) do
    Enum.map(input, fn {_, code} ->
      convert2key(code)
    end)
    |> execute(session, subname, subargs)
  end

  def process(input, session) when is_list(input) do
    Enum.map(input, fn {_, code} ->
      convert2key(code)
    end)
    |> execute(session)
  end

  def process(_input, _session) do

  end

  defp execute(code, session, subname \\ "", subargs \\ %{}) do
    if Keyword.keyword?(code) do
      execute_sub_workflow(code, session, subname, subargs)
    else
      execute_sequence(code, session)
    end
  end

  defp execute_sub_workflow(code, session, subname, subargs) do
    # WIP: support for subworkflow
    Enum.map(code, fn {k, v} ->
      record_sub_workflow(session, k, v)
    end)
    extract_sub_workflow_code(session, subname, subargs)
    |> execute_sequence(session)
    clear_all(session)
  end

  defp execute_sequence(code, session) do
    #Logger.log(:debug, "execute code sequence: #{inspect code}")

    Enum.map(code, fn {k, v} ->
      record_next(session, k, v)
      record_call(session, k, v)
    end)
    code
    |> Enum.map(fn {k,v} ->
      exec_command(session, k, v)
    end)
    exec_delayed(session)
    # clear state
    Enum.map(code, fn {k, _} ->
      clear(session, k)
    end)
    clear_all(session)
  end

  defp exec_command(session, uid, scripts) do
    #Logger.log(:debug, "exec_command session: #{session}, uid: #{uid}, scripts: #{inspect scripts}")
    if (delayed = DelayedExec.value(session)) != nil do
      if delayed == uid do
        DelayedExec.reset(session, nil)
        Enum.map(scripts, fn p ->
          command(session, uid, p)
        end)
      end
    else
      Enum.map(scripts, fn p ->
        command(session, uid, p)
      end)
    end
  end

  defp exec_delayed(session) do
    if (val = DelayedExec.value(session)) != nil do
      DelayedExec.reset(session, nil)
      if (next_exec = Storages.get_next_exec_by(%{"session" => session, "uid" => val})) != nil do
        exec_command(session, next_exec.uid, :erlang.binary_to_term(next_exec.triggered_script))
      end
      exec_delayed(session)
    end
  end

  defp clear(session, uid) do
    #Logger.log(:debug, "clear session: #{session}, uid: #{uid}")
    DelayedExec.reset(session, nil)

    case Storages.get_function_by(%{"session" => session, "uid" => uid}) do
      nil -> nil
      func -> Storages.delete_function(func)
    end

    case Storages.get_next_exec_by(%{"session" => session, "uid" => uid}) do
      nil -> nil
      next_exec -> Storages.delete_next_exec(next_exec)
    end
  end

  defp extract_sub_workflow_code(session, uid, subargs \\ %{}) do
    module_name = String.to_existing_atom("#{@default_module_prefix}.SubWorkflow")
    func =
      case uid do
        "" -> Storages.get_first_function_by(%{"session" => session, "module" => module_name})
        other -> Storages.get_function_by(%{"session" => session, "uid" => other})
      end
    args =
      :maps.filter(fn k,_ ->
        Map.has_key?(:erlang.binary_to_term(func.args), k)
      end, subargs)
    default_args =
      :maps.filter(fn k,v ->
        v != nil && not Map.has_key?(args, k)
      end, :erlang.binary_to_term(func.args))
    args =
      Map.merge(args, default_args)
      |> Enum.map(fn {k, v} ->
        [[k, v]]
      end)
    steps =
      [:erlang.binary_to_term(func.name)]
      |> Enum.map(fn [k,v] -> {String.to_existing_atom(k),v} end)
    cond do
      length(args) == 0 -> [{func.uid, steps}]
      true -> [{func.uid, [params: args] ++ steps}]
    end
  end

  defp clear_all(session) do
    funcs = Storages.list_functions_by(%{"session" => session})
    Enum.each(funcs, fn f ->
      Storages.delete_function(f)
    end)
  end

  defp record_sub_workflow(session, uid, scripts) do
    #Logger.log(:debug, "#{session}, #{uid}: #{inspect scripts}")

    case Storages.get_function_by(%{"session" => session, "uid" => Atom.to_string(uid)}) do
      nil ->
        {:params, args} = case scripts
        |> Enum.filter(fn {k, _} -> k == :params end)
        |> Enum.at(0) do
          nil -> {:params, %{}}
          other -> other
        end

        args =
          args
          |> Enum.map(fn it -> String.split(it, ":") |> Enum.map(fn i -> String.trim(i) end) end)
          |> Enum.map(fn it ->
            case it do
              [k] -> {k, nil}
              [k,v] -> {k, v}
              _ -> nil
            end
          end)
          |> Enum.filter(fn it -> it != nil end)
          |> Enum.into(%{})

        #Logger.log(:debug, "#{inspect args}")

        {:steps, steps} =
          case scripts
          |> Enum.filter(fn {k, _} -> k == :steps end)
          |> Enum.at(0) do
            nil -> {:steps, nil}
            other -> other
          end

        #Logger.log(:debug, "#{inspect steps}")

        module_name = String.to_existing_atom("#{@default_module_prefix}.SubWorkflow")

        Storages.create_function(%{
          "session" => session,
          "uid" => Atom.to_string(uid),
          "args" => :erlang.term_to_binary(args),
          "module" => :erlang.term_to_binary(module_name),
          "name" => :erlang.term_to_binary(["steps", steps])
        })
      _ -> nil
    end
  end

  defp record_next(session, uid, scripts) do
    #Logger.log(:debug, "#{session}, #{uid}: #{inspect scripts}")

    # check for next, then add to the storages
    if length(Keyword.take(scripts, [:next])) > 0 do
      {:next, nextval} = scripts
      |> Enum.filter(fn {k, _} -> k == :next end)
      |> Enum.at(0)

      #Logger.log(:debug, "record_next session: #{session}, uid: #{uid}, scripts: #{inspect scripts}")
      timestamp = :os.system_time(:microsecond)
      if (next_exec = Storages.get_next_exec_by(%{"session" => session, "uid" => uid})) != nil do
        Storages.update_next_exec(next_exec, %{
          "next_uid" => nextval,
          "triggered_script" => :erlang.term_to_binary(scripts),
          "updated_at" => timestamp
        })
      else
        Storages.create_next_exec(%{
          "session" => session,
          "uid" => uid,
          "next_uid" => nextval,
          "is_executed" => false,
          "triggered_script" => :erlang.term_to_binary(scripts),
          "has_cond_value" => false,
          "inserted_at" => timestamp,
          "updated_at" => timestamp
        })
      end

      if nextval not in @halt_exec and Storages.get_next_exec_by(%{"session" => session, "uid" => nextval}) == nil do
        timestamp = :os.system_time(:microsecond)
        Storages.create_next_exec(%{
          "session" => session,
          "uid" => nextval,
          "is_executed" => false,
          "has_cond_value" => false,
          "inserted_at" => timestamp,
          "updated_at" => timestamp
        })
      end
    else
      timestamp = :os.system_time(:microsecond)
      if (next_exec = Storages.get_next_exec_by(%{"session" => session, "uid" => uid})) != nil do
        Storages.update_next_exec(next_exec, %{
          "triggered_script" => :erlang.term_to_binary(scripts),
          "updated_at" => timestamp
        })
      else
        Storages.create_next_exec(%{
          "session" => session,
          "uid" => uid,
          "is_executed" => false,
          "triggered_script" => :erlang.term_to_binary(scripts),
          "has_cond_value" => false,
          "inserted_at" => timestamp,
          "updated_at" => timestamp
        })
      end
    end
  end

  defp record_call(session, uid, scripts) do
    if length(Keyword.take(scripts, [:call])) > 0 do
      #Logger.log(:debug, "record_call session: #{session}, uid: #{uid}, scripts: #{inspect scripts}")

      case Storages.get_function_by(%{"session" => session, "uid" => uid}) do
        nil ->
          {:call, name} = scripts
          |> Enum.filter(fn {k, _} -> k == :call end)
          |> Enum.at(0)

          {:args, args} = scripts
          |> Enum.filter(fn {k, _} -> k == :args end)
          |> Enum.at(0)

          args =
          case scripts |> Enum.filter(fn {k, _} -> k == :body end) |> Enum.at(0) do
            {:body, body} -> args ++ [["body", body]]
            nil -> args
          end

          sub_workflow_func = Storages.get_function_by(%{"session" => session, "uid" => name})
          if sub_workflow_func != nil and :erlang.binary_to_term(sub_workflow_func.module) == WorkflowDsl.SubWorkflow do
            module_name = String.to_existing_atom("#{@default_module_prefix}.SubWorkflow")
            args = args
              |> Enum.map(fn it ->
                case it do
                  [k] -> {k, nil}
                  [k,v] -> {k, v}
                  _ -> nil
                end
              end)
              |> Enum.filter(fn it -> it != nil end)
              |> Enum.into(%{})

            Storages.create_function(%{
              "session" => session,
              "uid" => uid,
              "args" => :erlang.term_to_binary(args),
              "module" => :erlang.term_to_binary(module_name),
              "name" => sub_workflow_func.name
            })
          else
            modfunc = String.split(String.capitalize(name), ".")
            module_name = String.to_existing_atom("#{@default_module_prefix}.#{Enum.at(modfunc,0)}")

            Storages.create_function(%{
              "session" => session,
              "uid" => uid,
              "args" => :erlang.term_to_binary(args),
              "module" => :erlang.term_to_binary(module_name),
              "name" => :erlang.term_to_binary(String.to_atom(Enum.at(modfunc, 1)))
            })
          end

        _ -> nil
      end
    end
  end

  # defp run_sub_workflow() do

  # end

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
      _ ->
        Logger.log(:debug, "#{inspect code}")
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
  defp to_keyword(["body", params]), do: {:body, params}
  defp to_keyword([func, params]), do: {:unknown, [func, params]}

  defp command(session, uid, {:assign, params}) do
    # holds the params value to ets
    Enum.map(params, fn [[varname, val]] ->
      CommandExecutor.execute_assign(session, varname, val)
    end)

    Logger.log(:debug, "assign: #{inspect params}, session: #{inspect session}, uid: #{inspect uid}")
  end

  defp command(session, uid, {:params, params}) do
    command(session, uid, {:assign, params})
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
    # check for sub_workflow or sequence
    func = Storages.get_function_by(%{"session" => session, "uid" => uid})
    if (func != nil) and (:erlang.binary_to_term(func.module) == Elixir.WorkflowDsl.SubWorkflow) do
      extract_sub_workflow_code(session, uid)
      |> execute_sequence(session)
    else
      CommandExecutor.maybe_execute_function(session, uid)
    end
    Logger.log(:debug, "call: #{inspect params}, session: #{inspect session}, uid: #{uid}")
  end

  defp command(session, uid, {:args, params}) do
    # check for sub_workflow or sequence
    if (func = Storages.get_function_by(%{"session" => session, "uid" => uid})) != nil do
      if is_nil(func.executed_at), do: CommandExecutor.maybe_execute_function(session, uid)
    end
    Logger.log(:debug, "args: #{inspect params}, session: #{inspect session}, uid: #{uid}")
  end

  defp command(session, uid, {:next, params}) do
    CommandExecutor.execute_next(session, params)
    Logger.log(:debug, "next: #{inspect params}, session: #{inspect session}, uid: #{uid}")
  end

  defp command(session, uid, {:result, params}) do
    # assign the result to var table
    CommandExecutor.execute_result(session, uid, params)
    Logger.log(:debug, "result: #{inspect params}, session: #{inspect session}, uid: #{uid}")
  end

  defp command(session, uid, {:switch, params}) do
    # case for condition -> next
    # case for condition -> return
    # case for condition -> steps
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
    #Logger.log(:debug, "#{inspect result}")

    case CommandExecutor.execute_switch(session, uid, Enum.at(result,0)) do
      nil -> nil
      res ->
        Logger.log(:debug, "switch: #{inspect params}, session: #{inspect session}, uid: #{uid}, result: #{inspect res}")
    end
  end

  defp command(session, _uid, {:steps, params}) do
    CommandExecutor.execute_steps(session, params)
  end

  defp command(_session, _uid, {:body, _params}) do
    # ignore body command
    #CommandExecutor.execute_body(session, uid, params)
    #Logger.log(:debug, "body: #{inspect params}, session: #{inspect session}, uid: #{uid}")
  end

  defp command(session, uid, input) do
    Logger.log(:debug, "unknown command, session: #{inspect session}, uid: #{inspect uid}, input: #{inspect input}")
  end
end

# to fill the SubWorkflow module registration
defmodule WorkflowDsl.SubWorkflow, do: nil
