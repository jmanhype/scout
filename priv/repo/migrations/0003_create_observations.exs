
defmodule Scout.Repo.Migrations.CreateObservations do
  use Ecto.Migration
  
  def change do
    create table(:observations) do
      add :study_id, references(:studies, column: :id, type: :string, on_delete: :delete_all), null: false
      add :trial_id, references(:trials, column: :id, type: :string, on_delete: :delete_all), null: false
      add :step, :integer, null: false
      add :value, :float, null: false
      add :metadata, :map, default: %{}
      
      timestamps(updated_at: false)
    end
    
    create index(:observations, [:study_id])
    create index(:observations, [:trial_id])
    create unique_index(:observations, [:trial_id, :step])
  end
end
