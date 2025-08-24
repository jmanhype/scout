
defmodule Scout.Repo.Migrations.CreateStudies do
  use Ecto.Migration
  def change do
    create table(:scout_studies, primary_key: false) do
      add :id, :string, primary_key: true
      add :status, :string, null: false, default: "running"
      add :meta, :map, null: false
      timestamps()
    end
  end
end
