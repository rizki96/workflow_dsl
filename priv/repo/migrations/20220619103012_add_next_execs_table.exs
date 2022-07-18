defmodule WorkflowDsl.Repo.Migrations.AddNextExecsTable do
  use Ecto.Migration

  def change do
    create table(:next_execs, primary_key: false) do
      add :next_exec_id, :serial, primary_key: true
      add :uid, :string
      add :next_uid, :string
      add :parent_uid, :string, default: ""
      add :session, :string
      add :triggered_script, :binary
      add :is_executed, :boolean
      add :has_cond_value, :boolean

      timestamps(type: :utc_datetime_usec)
    end
  end
end
