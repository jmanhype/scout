
defmodule Scout.Store.Ecto.Study do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :string, []}
  schema "scout_studies" do
    field :status, :string, default: "running"
    field :meta, :map
    timestamps(updated_at: true)
  end
  def changeset(struct, attrs), do: struct |> cast(attrs, [:id, :meta, :status]) |> validate_required([:id, :meta])
end

defmodule Scout.Store.Ecto.Trial do
  use Ecto.Schema
  import Ecto.Changeset
  schema "scout_trials" do
    field :study_id, :string
    field :status, :string
    field :params, :map
    field :rung, :integer, default: 0
    field :score, :float
    field :metrics, :map, default: %{}
    field :error, :string
    field :seed, :integer
    timestamps()
  end
  def changeset(struct, attrs), do: struct |> cast(attrs, [:study_id, :status, :params, :rung, :score, :metrics, :error, :seed]) |> validate_required([:study_id, :status, :params])
end

defmodule Scout.Store.Ecto.Observation do
  use Ecto.Schema
  import Ecto.Changeset
  schema "scout_observations" do
    field :trial_id, :integer
    field :rung, :integer
    field :score, :float
    timestamps(updated_at: false)
  end
  def changeset(struct, attrs), do: struct |> cast(attrs, [:trial_id, :rung, :score]) |> validate_required([:trial_id, :rung, :score])
end
