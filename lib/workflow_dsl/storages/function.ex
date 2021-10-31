defmodule WorkflowDsl.Storages.Function do
  use WorkflowDsl.Utils.Model
  @primary_key {:function_id, :id, autogenerate: true}

  schema "functions" do
    field :uid, :string
    field :session, :string
    field :module, :binary
    field :name, :binary
    field :args, :binary
    field :result, :binary
    field :executed_at, :integer
  end

  @spec changeset(:invalid | %{optional(:__struct__) => none, optional(atom | binary) => any}) :: any
  def changeset(params \\ %{}) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(model , params) do
    fields = __MODULE__.__schema__(:fields)
    embeds = __MODULE__.__schema__(:embeds)
    cast_model = cast(model, params, fields -- embeds)

    Enum.reduce(embeds, cast_model, fn embed, model ->
      cast_embed(model, embed)
    end)
  end

end
