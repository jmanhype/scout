defmodule Scout.Repo.Migrations.CreateStudies do
  use Ecto.Migration

  def up do
    # Enable UUID extension
    execute "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\""
    
    create table(:studies, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :name, :text, null: false
      add :goal, :text, null: false
      add :status, :text, null: false, default: "pending"
      add :max_trials, :integer, null: false, default: 100
      add :parallelism, :integer, null: false, default: 1
      add :seed, :bigint
      add :sampler_config, :map, null: false, default: %{}
      add :pruner_config, :map, null: false, default: %{}
      add :search_space, :map, null: false, default: %{}
      add :metadata, :map, null: false, default: %{}
      add :best_trial_id, :uuid
      add :best_score, :float
      add :completed_at, :utc_datetime
      
      timestamps()
    end
    
    # Constraints
    create unique_index(:studies, [:name])
    create index(:studies, [:status])
    create index(:studies, [:goal])
    create index(:studies, [:completed_at])
    
    # Check constraints
    execute """
    ALTER TABLE studies ADD CONSTRAINT studies_goal_check 
    CHECK (goal IN ('maximize', 'minimize'))
    """
    
    execute """
    ALTER TABLE studies ADD CONSTRAINT studies_status_check 
    CHECK (status IN ('pending', 'running', 'completed', 'failed', 'cancelled'))
    """
    
    execute """
    ALTER TABLE studies ADD CONSTRAINT studies_max_trials_positive 
    CHECK (max_trials > 0)
    """
    
    execute """
    ALTER TABLE studies ADD CONSTRAINT studies_parallelism_positive 
    CHECK (parallelism > 0)
    """
  end

  def down do
    drop table(:studies)
  end
end