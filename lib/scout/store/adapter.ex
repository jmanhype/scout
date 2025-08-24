defmodule Scout.Store.Adapter do
  @moduledoc """
  Behaviour for Scout storage adapters.
  
  Implementations must provide storage for studies, trials, and observations.
  Currently implemented by:
  - Scout.Store.ETS (in-memory, fast, non-persistent)
  - Scout.Store.Postgres (persistent, distributed-ready)
  """
  
  @type study_id :: String.t()
  @type trial_id :: String.t()
  @type error :: {:error, term()}
  
  # Study callbacks
  @callback put_study(map()) :: :ok | error()
  @callback get_study(study_id()) :: {:ok, map()} | error()
  @callback list_studies() :: [map()]
  @callback delete_study(study_id()) :: :ok | error()
  
  # Trial callbacks
  @callback put_trial(study_id(), map()) :: :ok | error()
  @callback get_trial(study_id(), trial_id()) :: {:ok, map()} | error()
  @callback list_trials(study_id()) :: [map()]
  @callback update_trial(study_id(), trial_id(), map()) :: :ok | error()
  @callback delete_trial(study_id(), trial_id()) :: :ok | error()
  
  # Observation callbacks
  @callback put_observation(study_id(), trial_id(), map()) :: :ok | error()
  @callback list_observations(study_id(), trial_id()) :: [map()]
end