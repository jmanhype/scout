
defmodule Scout.Repo.Migrations.CreateTrials do
  use Ecto.Migration
  
  def change do
    create table(:trials, primary_key: false) do
      add :id, :string, primary_key: true
      add :study_id, references(:studies, column: :id, type: :string, on_delete: :delete_all), null: false
      add :number, :integer, null: false
      add :params, :map
      add :value, :float
      add :status, :string, default: "pending"
      add :metadata, :map, default: %{}
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime
      
      timestamps()
    end
    
    create index(:trials, [:study_id])
    create index(:trials, [:status])
    create unique_index(:trials, [:study_id, :number])
  end
end
