defmodule Scout.Store.Schemas.Trial do
  @moduledoc """
  Ecto schema for trials in PostgreSQL storage.
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  
  @primary_key {:id, :string, autogenerate: false}
  @foreign_key_type :string
  @timestamps_opts [type: :utc_datetime]
  
  schema "trials" do
    field :number, :integer
    field :params, :map
    field :value, :float
    field :status, :string, default: "pending"
    field :metadata, :map, default: %{}
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime
    
    belongs_to :study, Scout.Store.Schemas.Study
    has_many :observations, Scout.Store.Schemas.Observation
    
    timestamps()
  end
  
  @doc false
  def changeset(trial, attrs) do
    trial
    |> cast(attrs, [:id, :study_id, :number, :params, :value, :status, :metadata, :started_at, :completed_at])
    |> validate_required([:id, :study_id, :number])
    |> validate_inclusion(:status, ["pending", "running", "succeeded", "failed", "pruned"])
    |> foreign_key_constraint(:study_id)
    |> unique_constraint([:study_id, :id])
    |> unique_constraint([:study_id, :number])
  end
end