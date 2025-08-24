defmodule Scout.Store.Schemas.Study do
  @moduledoc """
  Ecto schema for studies in PostgreSQL storage.
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  
  @primary_key {:id, :string, autogenerate: false}
  @timestamps_opts [type: :utc_datetime]
  
  schema "studies" do
    field :goal, :string
    field :search_space, :map
    field :metadata, :map, default: %{}
    field :max_trials, :integer
    
    has_many :trials, Scout.Store.Schemas.Trial
    has_many :observations, Scout.Store.Schemas.Observation
    
    timestamps()
  end
  
  @doc false
  def changeset(study, attrs) do
    study
    |> cast(attrs, [:id, :goal, :search_space, :metadata, :max_trials])
    |> validate_required([:id, :goal])
    |> validate_inclusion(:goal, ["minimize", "maximize"])
    |> unique_constraint(:id)
  end
end