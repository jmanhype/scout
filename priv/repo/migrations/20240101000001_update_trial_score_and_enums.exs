defmodule Scout.Repo.Migrations.UpdateTrialScoreAndEnums do
  use Ecto.Migration

  def change do
    # Rename value column to score
    rename table(:trials), :value, to: :score
    
    # Convert status strings to enum-compatible format
    execute """
    ALTER TABLE trials 
    ALTER COLUMN status TYPE VARCHAR(20)
    """, ""
    
    execute """
    ALTER TABLE studies
    ALTER COLUMN goal TYPE VARCHAR(20)
    """, ""
    
    # Add status column to studies if not exists
    alter table(:studies) do
      add_if_not_exists :status, :string, default: "running"
    end
    
    # Add constraints for enum values
    create constraint(:trials, :valid_trial_status, 
      check: "status IN ('pending', 'running', 'succeeded', 'failed', 'pruned')")
    
    create constraint(:studies, :valid_study_goal,
      check: "goal IN ('minimize', 'maximize')")
      
    create constraint(:studies, :valid_study_status,
      check: "status IN ('pending', 'running', 'completed', 'failed', 'cancelled')")
  end

  def down do
    # Remove constraints
    drop constraint(:studies, :valid_study_status)
    drop constraint(:studies, :valid_study_goal)
    drop constraint(:trials, :valid_trial_status)
    
    # Rename score back to value
    rename table(:trials), :score, to: :value
    
    # Remove status from studies
    alter table(:studies) do
      remove_if_exists :status, :string
    end
  end
end