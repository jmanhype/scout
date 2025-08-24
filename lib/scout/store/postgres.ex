defmodule Scout.Store.Postgres do
  @moduledoc """
  PostgreSQL storage adapter for Scout.
  
  Provides persistent storage across restarts and enables distributed optimization
  by storing all data in PostgreSQL instead of ETS.
  """
  
  alias Scout.Repo
  alias Scout.Store.Schemas.{Study, Trial, Observation}
  import Ecto.Query
  
  @behaviour Scout.Store.Adapter
  
  # Study operations
  
  @impl true
  def put_study(study_map) do
    changeset = Study.changeset(%Study{}, study_map)
    
    case Repo.insert(changeset, on_conflict: :replace_all, conflict_target: :id) do
      {:ok, _study} -> :ok
      {:error, changeset} -> {:error, changeset}
    end
  end
  
  @impl true
  def get_study(study_id) do
    case Repo.get(Study, study_id) do
      nil -> {:error, :not_found}
      study -> {:ok, study_to_map(study)}
    end
  end
  
  @impl true
  def list_studies do
    Study
    |> Repo.all()
    |> Enum.map(&study_to_map/1)
  end
  
  @impl true
  def delete_study(study_id) do
    # Cascading deletes should handle trials and observations
    case Repo.get(Study, study_id) do
      nil -> {:error, :not_found}
      study ->
        case Repo.delete(study) do
          {:ok, _} -> :ok
          error -> error
        end
    end
  end
  
  # Trial operations
  
  @impl true
  def put_trial(study_id, trial_map) do
    trial_map = Map.put(trial_map, :study_id, study_id)
    changeset = Trial.changeset(%Trial{}, trial_map)
    
    case Repo.insert(changeset, on_conflict: :replace_all, conflict_target: [:study_id, :id]) do
      {:ok, _trial} -> :ok
      {:error, changeset} -> {:error, changeset}
    end
  end
  
  @impl true
  def get_trial(study_id, trial_id) do
    query = from t in Trial,
      where: t.study_id == ^study_id and t.id == ^trial_id
    
    case Repo.one(query) do
      nil -> {:error, :not_found}
      trial -> {:ok, trial_to_map(trial)}
    end
  end
  
  @impl true
  def list_trials(study_id) do
    query = from t in Trial,
      where: t.study_id == ^study_id,
      order_by: [asc: t.number]
    
    query
    |> Repo.all()
    |> Enum.map(&trial_to_map/1)
  end
  
  @impl true
  def update_trial(study_id, trial_id, updates) do
    query = from t in Trial,
      where: t.study_id == ^study_id and t.id == ^trial_id
    
    case Repo.one(query) do
      nil -> {:error, :not_found}
      trial ->
        changeset = Trial.changeset(trial, updates)
        case Repo.update(changeset) do
          {:ok, _trial} -> :ok
          error -> error
        end
    end
  end
  
  @impl true
  def delete_trial(study_id, trial_id) do
    query = from t in Trial,
      where: t.study_id == ^study_id and t.id == ^trial_id
    
    case Repo.one(query) do
      nil -> {:error, :not_found}
      trial ->
        case Repo.delete(trial) do
          {:ok, _} -> :ok
          error -> error
        end
    end
  end
  
  # Observation operations
  
  @impl true
  def put_observation(study_id, trial_id, observation_map) do
    observation_map = observation_map
      |> Map.put(:study_id, study_id)
      |> Map.put(:trial_id, trial_id)
    
    changeset = Observation.changeset(%Observation{}, observation_map)
    
    case Repo.insert(changeset) do
      {:ok, _observation} -> :ok
      {:error, changeset} -> {:error, changeset}
    end
  end
  
  @impl true
  def list_observations(study_id, trial_id) do
    query = from o in Observation,
      where: o.study_id == ^study_id and o.trial_id == ^trial_id,
      order_by: [asc: o.step]
    
    query
    |> Repo.all()
    |> Enum.map(&observation_to_map/1)
  end
  
  # Helper functions to convert between Ecto schemas and maps
  
  defp study_to_map(%Study{} = study) do
    %{
      id: study.id,
      goal: String.to_existing_atom(study.goal),
      search_space: study.search_space,
      metadata: study.metadata || %{},
      max_trials: study.max_trials,
      created_at: study.inserted_at,
      updated_at: study.updated_at
    }
  end
  
  defp trial_to_map(%Trial{} = trial) do
    %{
      id: trial.id,
      study_id: trial.study_id,
      number: trial.number,
      params: trial.params,
      value: trial.value,
      status: String.to_existing_atom(trial.status),
      metadata: trial.metadata || %{},
      started_at: trial.started_at,
      completed_at: trial.completed_at,
      created_at: trial.inserted_at,
      updated_at: trial.updated_at
    }
  end
  
  defp observation_to_map(%Observation{} = observation) do
    %{
      id: observation.id,
      study_id: observation.study_id,
      trial_id: observation.trial_id,
      step: observation.step,
      value: observation.value,
      metadata: observation.metadata || %{},
      created_at: observation.inserted_at
    }
  end
end