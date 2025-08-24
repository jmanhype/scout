defmodule Scout.Repo.Migrations.AddStudyBestTrialFk do
  use Ecto.Migration

  def up do
    # Add foreign key constraint for best_trial_id in studies table
    # This ensures referential integrity - best trial must exist
    execute """
    ALTER TABLE studies 
    ADD CONSTRAINT studies_best_trial_id_fkey 
    FOREIGN KEY (best_trial_id) REFERENCES trials(id) ON DELETE SET NULL
    """
  end

  def down do
    execute "ALTER TABLE studies DROP CONSTRAINT IF EXISTS studies_best_trial_id_fkey"
  end
end