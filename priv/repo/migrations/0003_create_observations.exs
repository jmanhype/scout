
defmodule Scout.Repo.Migrations.CreateObservations do
  use Ecto.Migration
  def change do
    create table(:scout_observations) do
      add :trial_id, references(:scout_trials, on_delete: :delete_all), null: false
      add :rung, :integer, null: false
      add :score, :float, null: false
      timestamps(updated_at: false)
    end
    create index(:scout_observations, [:trial_id, :rung])
  end
end
