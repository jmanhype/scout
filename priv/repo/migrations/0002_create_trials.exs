
defmodule Scout.Repo.Migrations.CreateTrials do
  use Ecto.Migration
  def change do
    create table(:scout_trials) do
      add :study_id, references(:scout_studies, column: :id, type: :string, on_delete: :delete_all), null: false
      add :status, :string, null: false
      add :params, :map, null: false
      add :rung, :integer, default: 0
      add :score, :float
      add :metrics, :map, default: %{}, null: false
      add :error, :text
      add :seed, :bigint
      timestamps()
    end
    create index(:scout_trials, [:study_id])
    create index(:scout_trials, [:status])
  end
end
