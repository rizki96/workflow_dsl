defmodule WorkflowDsl.Repo.Migrations.AddVarsTable do
  use Ecto.Migration

  def change do
    create table(:vars, primary_key: false) do
      add :var_id, :serial, primary_key: true
      add :session, :string
      add :name, :string
      add :typ, :string
      add :value, :binary
    end
  end
end
