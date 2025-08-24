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
    
    # FIXED: Use explicit column updates instead of :replace_all to prevent data loss
    case Repo.insert(changeset, 
                     on_conflict: [set: [goal: changeset.changes[:goal], 
                                        search_space: changeset.changes[:search_space],
                                        metadata: changeset.changes[:metadata],
                                        max_trials: changeset.changes[:max_trials],
                                        updated_at: {:placeholder, :now}]],
                     conflict_target: :id,
                     placeholders: %{now: DateTime.utc_now()}) do
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
  
  @impl true
  def set_study_status(study_id, status) do
    query = from s in Study, where: s.id == ^study_id
    case Repo.one(query) do
      nil -> {:error, :not_found}
      study ->
        changeset = Study.changeset(study, %{status: Atom.to_string(status)})
        case Repo.update(changeset) do
          {:ok, _} -> :ok
          error -> error
        end
    end
  end

  # Trial operations
  
  @impl true
  def add_trial(study_id, trial_map) do
    trial_map = Map.put(trial_map, :study_id, study_id)
    changeset = Trial.changeset(%Trial{}, trial_map)
    
    case Repo.insert(changeset) do
      {:ok, trial} -> {:ok, trial.id}
      {:error, changeset} -> {:error, changeset}
    end
  end
  
  @impl true
  def fetch_trial(study_id, trial_id) do
    get_trial(study_id, trial_id)
  end
  
  @impl true 
  def list_trials(study_id, _filters \\ []) do
    query = from t in Trial,
      where: t.study_id == ^study_id,
      order_by: [asc: t.number]
    
    query
    |> Repo.all()
    |> Enum.map(&trial_to_map/1)
  end

  @impl true
  def put_trial(study_id, trial_map) do
    trial_map = Map.put(trial_map, :study_id, study_id)
    changeset = Trial.changeset(%Trial{}, trial_map)
    
    # FIXED: Use explicit column updates instead of :replace_all to prevent data loss
    case Repo.insert(changeset,
                     on_conflict: [set: [params: changeset.changes[:params],
                                        value: changeset.changes[:value], 
                                        status: changeset.changes[:status],
                                        metadata: changeset.changes[:metadata],
                                        started_at: changeset.changes[:started_at],
                                        completed_at: changeset.changes[:completed_at],
                                        updated_at: {:placeholder, :now}]],
                     conflict_target: [:study_id, :id],
                     placeholders: %{now: DateTime.utc_now()}) do
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
  def record_observation(study_id, trial_id, bracket, rung, score) do
    observation_map = %{
      study_id: study_id,
      trial_id: trial_id,
      step: rung,  # Map rung to step
      value: score,
      metadata: %{bracket: bracket, rung: rung}
    }
    
    changeset = Observation.changeset(%Observation{}, observation_map)
    
    case Repo.insert(changeset) do
      {:ok, _observation} -> :ok
      {:error, changeset} -> {:error, changeset}
    end
  end
  
  @impl true
  def observations_at_rung(study_id, bracket, rung) do
    query = from o in Observation,
      where: o.study_id == ^study_id and 
             fragment("?->>'bracket'", o.metadata) == ^to_string(bracket) and
             fragment("?->>'rung'", o.metadata) == ^to_string(rung),
      order_by: [asc: o.step]
    
    query
    |> Repo.all()
    |> Enum.map(&{&1.trial_id, &1.value})
  end
  
  @impl true
  def health_check do
    try do
      Ecto.Adapters.SQL.query!(Repo, "SELECT 1", [])
      :ok
    rescue
      _ -> {:error, :database_unavailable}
    end
  end
  
  # Legacy observation methods (for backward compatibility)
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