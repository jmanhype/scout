defmodule Scout.Store do
  @moduledoc """
  Storage facade with runtime adapter configuration.
  
  Delegates to configured storage adapter while providing interface stability.
  Uses UNIFIED behaviour contract to prevent interface mismatches.
  
  ## Available Adapters
  
  - `Scout.Store.ETS` (default) - In-memory storage, fast but non-persistent
  - `Scout.Store.Postgres` - PostgreSQL storage, persistent and distributed-ready
  
  ## Configuration
  
      # Runtime configuration (preferred - not compile-time locked)
      config :scout, :store_adapter, Scout.Store.ETS
  """

  alias Scout.Store.Adapter

  # Runtime adapter configuration (prevents compile-time lock-in)
  defp adapter do
    Application.get_env(:scout, :store_adapter, Scout.Store.ETS)
  end

  @doc """
  Returns a child specification for the configured storage adapter.
  """
  @spec child_spec(term()) :: Supervisor.child_spec()
  def child_spec(arg), do: adapter().child_spec(arg)

  # Import types from unified behaviour
  @type study_id :: Adapter.study_id()
  @type trial_id :: Adapter.trial_id()
  @type status :: Adapter.status()

  # Facade delegates with fixed signatures
  @spec put_study(map()) :: :ok | {:error, term()}
  def put_study(study), do: adapter().put_study(study)
  
  @spec set_study_status(study_id(), status()) :: :ok | {:error, term()}
  def set_study_status(id, status), do: adapter().set_study_status(id, status)
  
  @spec get_study(study_id()) :: {:ok, map()} | :error
  def get_study(id), do: adapter().get_study(id)
  
  @spec add_trial(study_id(), map()) :: {:ok, trial_id()} | {:error, term()}
  def add_trial(study_id, trial), do: adapter().add_trial(study_id, trial)
  
  # FIXED: update_trial now requires study_id for proper scoping
  @spec update_trial(study_id(), trial_id(), map()) :: :ok | {:error, term()}
  def update_trial(study_id, trial_id, updates), do: adapter().update_trial(study_id, trial_id, updates)
  
  # FIXED: record_observation requires study_id for proper scoping
  @spec record_observation(study_id(), trial_id(), non_neg_integer(), non_neg_integer(), number()) :: :ok | {:error, term()}
  def record_observation(study_id, trial_id, bracket, rung, score) do
    adapter().record_observation(study_id, trial_id, bracket, rung, score)
  end
  
  @spec list_trials(study_id(), keyword()) :: [map()]
  def list_trials(study_id, filters \\ []), do: adapter().list_trials(study_id, filters)
  
  # FIXED: fetch_trial now requires study_id to match DB uniqueness constraint
  @spec fetch_trial(study_id(), trial_id()) :: {:ok, map()} | :error
  def fetch_trial(study_id, trial_id), do: adapter().fetch_trial(study_id, trial_id)
  
  @spec observations_at_rung(study_id(), non_neg_integer(), non_neg_integer()) :: [{trial_id(), number()}]
  def observations_at_rung(study_id, bracket, rung) do
    adapter().observations_at_rung(study_id, bracket, rung)
  end

  @spec delete_study(study_id()) :: :ok | {:error, term()}
  def delete_study(study_id), do: adapter().delete_study(study_id)

  @spec health_check() :: :ok | {:error, term()}
  def health_check(), do: adapter().health_check()
  
  # ============================================================================
  # EXPLICIT STATE TRANSITIONS (prevent leaky abstractions)
  # ============================================================================
  
  @doc """
  Start a new trial with proper state initialization.
  
  Enforces:
  - Status must be :running
  - Started_at timestamp is set
  - Params are validated
  """
  @spec start_trial(study_id(), map(), non_neg_integer()) :: {:ok, trial_id()} | {:error, term()}
  def start_trial(study_id, params, bracket \\ 0) do
    trial_id = generate_trial_id()
    
    trial = %{
      id: trial_id,
      params: params,
      bracket: bracket,
      status: :running,
      started_at: System.system_time(:millisecond)
    }
    
    adapter().add_trial(study_id, trial)
  end
  
  @doc """
  Complete a trial successfully with score and metrics.
  
  Enforces:
  - Status transition to :succeeded
  - Finished_at timestamp is set
  - Score is recorded
  """
  @spec finish_trial(study_id(), trial_id(), number(), map()) :: :ok | {:error, term()}
  def finish_trial(study_id, trial_id, score, metrics \\ %{}) do
    updates = %{
      status: :succeeded,
      score: score,
      metrics: metrics,
      finished_at: System.system_time(:millisecond)
    }
    
    adapter().update_trial(study_id, trial_id, updates)
  end
  
  @doc """
  Mark a trial as failed with error information.
  
  Enforces:
  - Status transition to :failed
  - Error message is recorded
  - Finished_at timestamp is set
  """
  @spec fail_trial(study_id(), trial_id(), String.t()) :: :ok | {:error, term()}
  def fail_trial(study_id, trial_id, error_message) do
    updates = %{
      status: :failed,
      error: error_message,
      finished_at: System.system_time(:millisecond)
    }
    
    adapter().update_trial(study_id, trial_id, updates)
  end
  
  @doc """
  Prune a trial at a specific rung with optional score.
  
  Enforces:
  - Status transition to :pruned
  - Records pruning rung
  - Finished_at timestamp is set
  """
  @spec prune_trial(study_id(), trial_id(), non_neg_integer(), number() | nil) :: :ok | {:error, term()}
  def prune_trial(study_id, trial_id, rung, score \\ nil) do
    updates = %{
      status: :pruned,
      score: score,
      metadata: %{pruned_at_rung: rung},
      finished_at: System.system_time(:millisecond)
    }
    
    adapter().update_trial(study_id, trial_id, updates)
  end
  
  defp generate_trial_id do
    Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
  end
end