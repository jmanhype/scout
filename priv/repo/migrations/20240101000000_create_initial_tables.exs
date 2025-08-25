defmodule Scout.Repo.Migrations.CreateInitialTables do
  use Ecto.Migration

  def change do
    # Create studies table
    create table(:studies, primary_key: false) do
      add :id, :string, primary_key: true
      add :name, :string
      add :goal, :string
      add :params_spec, :map
      add :status, :string
      add :metadata, :map, default: %{}
      
      timestamps()
    end
    
    create index(:studies, [:status])
    
    # Create trials table
    create table(:trials, primary_key: false) do
      add :id, :string, primary_key: true
      add :study_id, references(:studies, type: :string, on_delete: :delete_all), null: false
      add :number, :integer
      add :params, :map
      add :value, :float  # Will be renamed to score in next migration
      add :status, :string
      add :metadata, :map, default: %{}
      add :started_at, :naive_datetime
      add :completed_at, :naive_datetime
      
      timestamps()
    end
    
    create index(:trials, [:study_id])
    create index(:trials, [:status])
    create unique_index(:trials, [:study_id, :number])
    
    # Create observations table
    create table(:observations, primary_key: false) do
      add :id, :string, primary_key: true
      add :trial_id, references(:trials, type: :string, on_delete: :delete_all), null: false
      add :step, :integer
      add :value, :float
      add :metadata, :map, default: %{}
      
      timestamps()
    end
    
    create index(:observations, [:trial_id])
    create unique_index(:observations, [:trial_id, :step])
  end
end