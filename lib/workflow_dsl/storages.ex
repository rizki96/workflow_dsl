defmodule WorkflowDsl.Storages do

  import Ecto.Query, warn: false

  alias WorkflowDsl.Repo
  alias WorkflowDsl.Storages.Var
  alias WorkflowDsl.Storages.Function
  alias WorkflowDsl.Storages.NextExec

  def list_vars() do
    Var
    |> Repo.all()
  end

  def get_var!(id) do
    Var
    |> Repo.get!(id)
  end

  def get_var_by(%{"session" => session, "name" => name}) do
    Var
    |> Repo.get_by(session: session, name: name)
  end

  def create_var(attrs) do
    %Var{}
    |> Var.changeset(attrs)
    |> Repo.insert()
  end

  def update_var(%Var{} = var, attrs) do
    var
    |> Var.changeset(attrs)
    |> Repo.update()
  end

  def delete_var(%Var{} = var) do
    Repo.delete(var)
  end

  def change_var(%Var{} = var, attrs \\ %{}) do
    Var.changeset(var, attrs)
  end

  def list_functions() do
    Function
    |> Repo.all()
  end

  def get_function!(id) do
    Function
    |> Repo.get!(id)
  end

  def get_function_by(%{"session" => session, "uid" => uid}) do
    Function
    |> Repo.get_by(session: session, uid: uid)
  end

  def get_last_function_executed() do
    Function
    #|> where()
    |> Repo.all()
    |> Enum.reduce([], fn it, acc ->
      case acc do
        [] -> if not is_nil(it.executed_at), do: [it], else: []
        [l] ->
          if not is_nil(it.executed_at) do
            if (l.executed_at > it.executed_at), do: [l], else: [it]
          else
            [l]
          end
      end
    end)
    |> Enum.at(0)
  end

  def create_function(attrs) do
    %Function{}
    |> Function.changeset(attrs)
    |> Repo.insert()
  end

  def update_function(%Function{} = function, attrs) do
    function
    |> Function.changeset(attrs)
    |> Repo.update()
  end

  def delete_function(%Function{} = function) do
    Repo.delete(function)
  end

  def delete_all_functions() do
    #Function
    #|> Repo.delete_all()
    :ets.delete(Function)
  end

  def change_function(%Function{} = function, attrs \\ %{}) do
    Function.changeset(function, attrs)
  end

  def list_next_execs() do
    NextExec
    |> Repo.all()
  end

  def list_next_execs(%{"session" => session}) do
    NextExec
    |> where([ne], ne.session == ^session)
    |> Repo.all()
  end

  def count_next_execs(%{"session" => session}) do
    NextExec
    |> where([ne], ne.session == ^session)
    |> Repo.all()
    |> Enum.count
  end

  def get_next_exec!(id) do
    NextExec
    |> Repo.get!(id)
  end

  def get_next_exec_by(%{"session" => session, "uid" => uid, "is_executed" => executed}) do
    NextExec
    |> Repo.get_by([session: session, uid: uid, is_executed: executed])
  end

  def get_next_exec_by(%{"session" => session, "uid" => uid}) do
    NextExec
    |> Repo.get_by([session: session, uid: uid])
  end

  def get_next_exec_by(%{"session" => session, "next_uid" => next_uid}) do
    NextExec
    |> Repo.get_by([session: session, next_uid: next_uid])
  end

  def get_oldest_next_exec(%{"session" => session, "is_executed" => executed}) do
    NextExec
    |> where([ne], ne.session == ^session and ne.is_executed == ^executed and not is_nil(ne.inserted_at))
    |> Repo.all()
    |> Enum.reduce([], fn it, acc ->
      case acc do
        [] -> [it]
        [l] ->
          if (l.inserted_at <= it.inserted_at), do: [l], else: [it]
      end
    end)
    |> Enum.at(0)
  end

  def get_oldest_next_exec(%{"session" => session}) do
    NextExec
    |> where([ne], ne.session == ^session)
    |> Repo.all()
    |> Enum.reduce([], fn it, acc ->
      case acc do
        [] -> [it]
        [l] ->
          if (l.inserted_at <= it.inserted_at), do: [l], else: [it]
      end
    end)
    |> Enum.at(0)
  end

  def get_latest_next_exec(%{"session" => session}) do
    NextExec
    |> where([ne], ne.session == ^session)
    |> Repo.all()
    |> Enum.reduce([], fn it, acc ->
      case acc do
        [] -> [it]
        [l] ->
          if (l.inserted_at >= it.inserted_at), do: [l], else: [it]
      end
    end)
    |> Enum.at(0)
  end

  def create_next_exec(attrs) do
    %NextExec{}
    |> NextExec.changeset(attrs)
    |> Repo.insert()
  end

  def update_next_exec(%NextExec{} = next_exec, attrs) do
    next_exec
    |> NextExec.changeset(attrs)
    |> Repo.update()
  end

  def delete_next_exec(%NextExec{} = next_exec) do
    Repo.delete(next_exec)
  end

  def delete_all_next_execs() do
    #NextExec
    #|> Repo.delete_all()
    :ets.delete(NextExec)
  end

  def change_next_exec(%NextExec{} = next_exec, attrs \\ %{}) do
    NextExec.changeset(next_exec, attrs)
  end
end
