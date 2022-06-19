defmodule WorkflowDsl.Repo.Migrations.AddFunctionsTable do
  use Ecto.Migration

  def change do
    create table(:functions, primary_key: false) do
      add :function_id, :serial, primary_key: true
      add :uid, :string
      add :session, :string
      add :module, :binary
      add :name, :binary
      add :args, :binary
      add :result, :binary
      add :executed_at, :integer

      timestamps(inserted_at: :created_at)
    end
  end
end
