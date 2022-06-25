defmodule WorkflowDsl.Storages.NextExec do
  use WorkflowDsl.Utils.Model
  @primary_key {:next_exec_id, :id, autogenerate: true}

  schema "next_execs" do
    field :uid, :string
    field :session, :string
    field :next_uid, :string
    field :triggered_script, :binary
    field :is_executed, :boolean
    field :has_cond_value, :boolean
    # field :inserted_at, :integer
    # field :updated_at, :integer

    timestamps(type: :utc_datetime_usec)
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
