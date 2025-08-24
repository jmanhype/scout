
defmodule Scout.Repo.Migrations.CreateStudies do
  use Ecto.Migration
  
  def change do
    create table(:studies, primary_key: false) do
      add :id, :string, primary_key: true
      add :goal, :string, null: false
      add :search_space, :map
      add :metadata, :map, default: %{}
      add :max_trials, :integer
      
      timestamps()
    end
    
    create index(:studies, [:inserted_at])
  end
end
