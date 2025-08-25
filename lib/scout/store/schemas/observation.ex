defmodule Scout.Store.Schemas.Observation do
  @moduledoc """
  Ecto schema for observations in PostgreSQL storage.
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  
  @foreign_key_type :string
  @timestamps_opts [type: :utc_datetime]
  
  schema "observations" do
    field :step, :integer
    field :value, :float
    field :metadata, :map, default: %{}
    
    belongs_to :study, Scout.Store.Schemas.Study
    belongs_to :trial, Scout.Store.Schemas.Trial
    
    timestamps(updated_at: false)
  end
  
  @doc false
  def changeset(observation, attrs) do
    observation
    |> cast(attrs, [:study_id, :trial_id, :step, :value, :metadata])
    |> validate_required([:study_id, :trial_id, :step, :value])
    |> foreign_key_constraint(:study_id)
    |> foreign_key_constraint(:trial_id)
    |> unique_constraint([:trial_id, :step])
  end
end