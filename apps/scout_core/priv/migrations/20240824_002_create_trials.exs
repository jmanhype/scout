defmodule Scout.Repo.Migrations.CreateTrials do
  use Ecto.Migration

  def up do
    create table(:trials, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :study_id, references(:studies, type: :uuid, on_delete: :delete_all), null: false
      add :index, :integer, null: false
      add :status, :text, null: false, default: "pending"
      add :params, :map, null: false, default: %{}
      add :result, :float
      add :metadata, :map, null: false, default: %{}
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :pruned_at, :utc_datetime
      add :error_message, :text
      
      timestamps()
    end
    
    # Natural key: each trial has unique index within study
    create unique_index(:trials, [:study_id, :index])
    create index(:trials, [:study_id, :status])
    create index(:trials, [:study_id, :result])
    create index(:trials, [:status])
    create index(:trials, [:started_at])
    create index(:trials, [:completed_at])
    
    # Performance: composite index for common queries
    create index(:trials, [:study_id, :status, :result])
    
    # Check constraints
    execute """
    ALTER TABLE trials ADD CONSTRAINT trials_status_check 
    CHECK (status IN ('pending', 'running', 'completed', 'failed', 'pruned'))
    """
    
    execute """
    ALTER TABLE trials ADD CONSTRAINT trials_index_non_negative 
    CHECK (index >= 0)
    """
    
    # Conditional constraints using triggers (more complex logic)
    execute """
    CREATE OR REPLACE FUNCTION validate_trial_times() RETURNS TRIGGER AS $$
    BEGIN
      -- completed_at must be after started_at if both exist
      IF NEW.started_at IS NOT NULL AND NEW.completed_at IS NOT NULL THEN
        IF NEW.completed_at < NEW.started_at THEN
          RAISE EXCEPTION 'completed_at cannot be before started_at';
        END IF;
      END IF;
      
      -- result required for completed trials
      IF NEW.status = 'completed' AND NEW.result IS NULL THEN
        RAISE EXCEPTION 'completed trials must have a result';
      END IF;
      
      -- error_message required for failed trials
      IF NEW.status = 'failed' AND NEW.error_message IS NULL THEN
        RAISE EXCEPTION 'failed trials must have an error message';
      END IF;
      
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """
    
    execute """
    CREATE TRIGGER validate_trial_times_trigger
    BEFORE INSERT OR UPDATE ON trials
    FOR EACH ROW EXECUTE FUNCTION validate_trial_times();
    """
  end

  def down do
    execute "DROP TRIGGER IF EXISTS validate_trial_times_trigger ON trials"
    execute "DROP FUNCTION IF EXISTS validate_trial_times()"
    drop table(:trials)
  end
end