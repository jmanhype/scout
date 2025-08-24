defmodule Scout.Repo.Migrations.CreateObservations do
  use Ecto.Migration

  def up do
    create table(:observations, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :trial_id, references(:trials, type: :uuid, on_delete: :delete_all), null: false
      add :bracket, :integer, null: false, default: 0
      add :rung, :integer, null: false, default: 0
      add :score, :float, null: false
      add :metadata, :map, null: false, default: %{}
      
      timestamps(updated_at: false)  # observations are immutable
    end
    
    # Natural key: each observation is unique per trial/bracket/rung
    create unique_index(:observations, [:trial_id, :bracket, :rung])
    create index(:observations, [:trial_id, :rung])
    create index(:observations, [:bracket, :rung])
    create index(:observations, [:score])
    
    # Performance: for pruning queries
    create index(:observations, [:bracket, :rung, :score])
    
    # Check constraints
    execute """
    ALTER TABLE observations ADD CONSTRAINT observations_bracket_non_negative 
    CHECK (bracket >= 0)
    """
    
    execute """
    ALTER TABLE observations ADD CONSTRAINT observations_rung_non_negative 
    CHECK (rung >= 0)
    """
    
    execute """
    ALTER TABLE observations ADD CONSTRAINT observations_score_finite 
    CHECK (score IS NOT NULL AND score = score)  -- excludes NaN
    """
  end

  def down do
    drop table(:observations)
  end
end