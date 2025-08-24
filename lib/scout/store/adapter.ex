defmodule Scout.Store.Adapter do
  @moduledoc """
  UNIFIED behaviour for Scout storage adapters.
  
  This is the single source of truth for storage contracts.
  All adapters must implement exactly these callbacks.
  
  Implementations:
  - Scout.Store.ETS (in-memory, fast, non-persistent) 
  - Scout.Store.Postgres (persistent, distributed-ready)
  """
  
  @type study_id :: String.t()
  @type trial_id :: String.t()
  @type status :: :pending | :running | :completed | :failed | :pruned
  @type error :: {:error, term()}
  
  # Study callbacks
  @callback put_study(map()) :: :ok | error()
  @callback get_study(study_id()) :: {:ok, map()} | :error
  @callback set_study_status(study_id(), status()) :: :ok | error()
  @callback list_studies() :: [map()]
  @callback delete_study(study_id()) :: :ok | error()
  
  # Trial callbacks - NOTE: Fixed signature to include study_id everywhere
  @callback add_trial(study_id(), map()) :: {:ok, trial_id()} | error()
  @callback fetch_trial(study_id(), trial_id()) :: {:ok, map()} | :error
  @callback list_trials(study_id(), keyword()) :: [map()]  
  @callback update_trial(study_id(), trial_id(), map()) :: :ok | error()
  @callback delete_trial(study_id(), trial_id()) :: :ok | error()
  
  # Observation callbacks
  @callback record_observation(study_id(), trial_id(), non_neg_integer(), non_neg_integer(), number()) :: :ok | error()
  @callback observations_at_rung(study_id(), non_neg_integer(), non_neg_integer()) :: [{trial_id(), number()}]
  
  # Health check
  @callback health_check() :: :ok | error()
end