defmodule WorkflowDsl.Storages.Var do
  use WorkflowDsl.Utils.Model
  @primary_key {:var_id, :id, autogenerate: true}

  schema "vars" do
    field :session, :string
    field :name, :string
    field :typ, :string
    field :value, :binary
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
