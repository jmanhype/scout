defmodule Scout.StoreBehaviour do
  @moduledoc """
  Behaviour definition for Scout storage adapters.
  
  This behaviour defines the contract that all storage adapters must implement.
  It provides strong typing and clear contracts to prevent interface mismatches.
  """

  @type study_id :: String.t()
  @type trial_id :: String.t()
  @type trial_index :: non_neg_integer()
  @type bracket :: non_neg_integer()
  @type rung :: non_neg_integer()
  @type score :: number()
  @type status :: :pending | :running | :completed | :failed | :pruned

  @doc """
  Store a study configuration.
  Study must have an :id field.
  """
  @callback put_study(study :: map()) :: :ok | {:error, term()}

  @doc """
  Update study status.
  Status must be one of: :pending, :running, :completed, :failed
  """
  @callback set_study_status(study_id(), status()) :: :ok | {:error, term()}

  @doc """
  Retrieve a study by ID.
  """
  @callback get_study(study_id()) :: {:ok, map()} | :error

  @doc """
  Add a new trial to a study.
  Returns the generated trial ID.
  Trial must have :index field and optionally :id.
  """
  @callback add_trial(study_id(), trial :: map()) :: {:ok, trial_id()} | {:error, term()}

  @doc """
  Update trial status and/or other fields.
  Common updates: %{status: :completed, result: score}
  """
  @callback update_trial(trial_id(), updates :: map()) :: :ok | {:error, term()}

  @doc """
  Record an observation (score) for a trial at specific bracket/rung.
  Used by multi-fidelity algorithms like Hyperband.
  """
  @callback record_observation(trial_id(), bracket(), rung(), score()) :: :ok | {:error, term()}

  @doc """
  Get all observations at a specific bracket/rung for a study.
  Returns list of {trial_id, score} tuples.
  Used by pruners to make early stopping decisions.
  """
  @callback observations_at_rung(study_id(), bracket(), rung()) :: [{trial_id(), score()}]

  @doc """
  List trials for a study with optional filtering.
  Supports filters: status, limit, offset
  """
  @callback list_trials(study_id(), filters :: keyword()) :: [map()]

  @doc """
  Fetch a specific trial by ID.
  """
  @callback fetch_trial(trial_id()) :: {:ok, map()} | :error

  @doc """
  Delete all data for a study.
  WARNING: This is destructive and cannot be undone.
  """
  @callback delete_study(study_id()) :: :ok | {:error, term()}

  @doc """
  Health check for the storage backend.
  """
  @callback health_check() :: :ok | {:error, term()}
end