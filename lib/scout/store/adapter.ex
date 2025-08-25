defmodule Scout.Store.Adapter do
  @moduledoc """
  Frozen storage adapter behaviour for Scout.
  
  This is the SINGLE SOURCE OF TRUTH for storage contracts.
  All adapters MUST implement exactly these callbacks with these signatures.
  No deviations allowed.
  
  ## Implementations
  
  - `Scout.Store.ETS` - In-memory, fast, non-persistent, single-node
  - `Scout.Store.Postgres` - Persistent, ACID, distributed-ready
  
  ## Contract Guarantees
  
  1. **Study Scoping**: All trial operations require study_id
  2. **Atomicity**: Operations either succeed fully or fail with no side effects
  3. **Consistency**: Status transitions follow state machine rules
  4. **Isolation**: No cross-study contamination
  
  ## Format Stability
  
  Study and Trial maps MUST contain at minimum:
  - `:id` - Unique identifier (String)
  - `:status` - Current status atom
  - `:created_at` - Timestamp (integer milliseconds)
  - `:updated_at` - Timestamp (integer milliseconds)
  """
  
  # ============================================================================
  # TYPE SPECIFICATIONS
  # ============================================================================
  
  @typedoc "Study identifier - MUST be unique across system"
  @type study_id :: String.t()
  
  @typedoc "Trial identifier - MUST be unique within study"
  @type trial_id :: String.t()
  
  @typedoc "Status atoms - ONLY these values allowed"
  @type status :: :pending | :running | :completed | :failed | :pruned | :cancelled
  
  @typedoc "Standard error tuple"
  @type error :: {:error, term()}
  
  @typedoc "Bracket for multi-armed strategies"
  @type bracket :: non_neg_integer()
  
  @typedoc "Rung/checkpoint in pruning schedule"
  @type rung :: non_neg_integer()
  
  @typedoc "Objective score"
  @type score :: number()
  
  @typedoc "Filter options for list operations"
  @type filters :: keyword()
  
  # ============================================================================
  # STUDY OPERATIONS
  # ============================================================================
  
  @doc """
  Store a study configuration.
  
  ## Required Fields
  - `:id` - Unique study identifier
  - `:goal` - Either `:maximize` or `:minimize`
  
  ## Optional Fields
  - `:status` - Defaults to `:running`
  - `:max_trials` - Maximum trials to run
  - `:metadata` - Arbitrary metadata map
  
  ## Returns
  - `:ok` on success
  - `{:error, reason}` on failure
  
  ## Guarantees
  - Idempotent: Repeated calls with same ID update, not duplicate
  - Atomic: Either fully stored or not at all
  """
  @callback put_study(study :: map()) :: :ok | error()
  
  @doc """
  Retrieve a study by ID.
  
  ## Returns
  - `{:ok, study_map}` if found
  - `:error` if not found
  
  ## Guarantees
  - Read-only operation
  - Returns latest committed state
  """
  @callback get_study(study_id :: study_id()) :: {:ok, map()} | :error
  
  @doc """
  Update study status.
  
  ## Valid Transitions
  - `:pending` -> `:running`
  - `:running` -> `:completed` | `:failed` | `:cancelled`
  - Any -> `:cancelled` (force stop)
  
  ## Returns
  - `:ok` on success
  - `{:error, :invalid_transition}` if transition not allowed
  - `{:error, :not_found}` if study doesn't exist
  """
  @callback set_study_status(study_id :: study_id(), status :: status()) :: :ok | error()
  
  @doc """
  List all studies.
  
  ## Returns
  List of study maps, possibly empty.
  
  ## Guarantees
  - Never returns nil
  - Includes all fields stored with put_study
  """
  @callback list_studies() :: [map()]
  
  @doc """
  Delete a study and ALL associated data.
  
  ## Cascade Behavior
  - Deletes all trials for this study
  - Deletes all observations for this study
  - Cannot be undone
  
  ## Returns
  - `:ok` even if study didn't exist (idempotent)
  - `{:error, reason}` only on storage failure
  """
  @callback delete_study(study_id :: study_id()) :: :ok | error()
  
  # ============================================================================
  # TRIAL OPERATIONS
  # ============================================================================
  
  @doc """
  Add a trial to a study.
  
  ## Required Fields
  - `:id` - Unique trial identifier (or auto-generated)
  - `:params` - Parameter map
  - `:status` - Initial status (usually `:running`)
  
  ## Optional Fields
  - `:bracket` - For multi-armed strategies
  - `:seed` - RNG seed for reproducibility
  - `:started_at` - Start timestamp
  
  ## Returns
  - `{:ok, trial_id}` with assigned/generated ID
  - `{:error, :study_not_found}` if study doesn't exist
  - `{:error, reason}` on other failures
  
  ## Guarantees
  - Trial ID unique within study
  - Atomically increments study trial count
  """
  @callback add_trial(study_id :: study_id(), trial :: map()) :: {:ok, trial_id()} | error()
  
  @doc """
  Fetch a specific trial.
  
  ## Returns
  - `{:ok, trial_map}` if found
  - `:error` if not found
  
  ## Guarantees
  - Returns trial only if it belongs to specified study
  - Includes all fields from add_trial plus updates
  """
  @callback fetch_trial(study_id :: study_id(), trial_id :: trial_id()) :: {:ok, map()} | :error
  
  @doc """
  List trials for a study with optional filters.
  
  ## Filter Options
  - `:status` - Filter by status atom or list of atoms
  - `:bracket` - Filter by bracket number
  - `:limit` - Maximum trials to return
  - `:order_by` - Sort field (`:score`, `:created_at`, etc.)
  
  ## Returns
  List of trial maps, possibly empty.
  
  ## Guarantees
  - Only returns trials for specified study
  - Respects all filter constraints
  """
  @callback list_trials(study_id :: study_id(), filters :: filters()) :: [map()]
  
  @doc """
  Update trial fields.
  
  ## Common Updates
  - `:status` - Status transition
  - `:score` - Final objective value
  - `:metrics` - Additional metrics map
  - `:finished_at` - Completion timestamp
  - `:error` - Error message if failed
  
  ## Returns
  - `:ok` on success
  - `{:error, :not_found}` if trial doesn't exist
  - `{:error, reason}` on other failures
  
  ## Guarantees
  - Only updates specified fields
  - Maintains created_at timestamp
  - Updates updated_at timestamp
  """
  @callback update_trial(study_id :: study_id(), trial_id :: trial_id(), updates :: map()) :: :ok | error()
  
  @doc """
  Delete a trial and its observations.
  
  ## Returns
  - `:ok` even if trial didn't exist (idempotent)
  - `{:error, reason}` only on storage failure
  
  ## Guarantees
  - Cascades to delete trial's observations
  - Does NOT affect other trials
  """
  @callback delete_trial(study_id :: study_id(), trial_id :: trial_id()) :: :ok | error()
  
  # ============================================================================
  # OBSERVATION OPERATIONS
  # ============================================================================
  
  @doc """
  Record an intermediate observation for a trial.
  
  Used by pruners to track progress at checkpoints.
  
  ## Arguments
  - `study_id` - Study identifier
  - `trial_id` - Trial identifier  
  - `bracket` - Bracket assignment
  - `rung` - Checkpoint/rung number
  - `score` - Objective value at this checkpoint
  
  ## Returns
  - `:ok` on success
  - `{:error, reason}` on failure
  
  ## Guarantees
  - Idempotent: Repeated calls update, not duplicate
  - Preserves observation history
  """
  @callback record_observation(
    study_id :: study_id(),
    trial_id :: trial_id(),
    bracket :: bracket(),
    rung :: rung(),
    score :: score()
  ) :: :ok | error()
  
  @doc """
  Get all observations at a specific rung.
  
  Used by pruners to determine percentile cutoffs.
  
  ## Returns
  List of `{trial_id, score}` tuples for trials that reached this rung.
  
  ## Guarantees
  - Only includes trials from specified study and bracket
  - Returns latest score if multiple observations at rung
  """
  @callback observations_at_rung(
    study_id :: study_id(),
    bracket :: bracket(),
    rung :: rung()
  ) :: [{trial_id(), score()}]
  
  # ============================================================================
  # HEALTH & MAINTENANCE
  # ============================================================================
  
  @doc """
  Check storage adapter health.
  
  ## Returns
  - `:ok` if storage is accessible and functioning
  - `{:error, reason}` with specific failure reason
  
  ## Use Cases
  - Startup health checks
  - Monitoring/alerting
  - Graceful degradation
  """
  @callback health_check() :: :ok | error()
  
  # ============================================================================
  # ADAPTER VALIDATION
  # ============================================================================
  
  @doc """
  Runtime validation that a module implements Scout.Store.Adapter.
  Used by the facade to verify configured adapters.
  """
  @spec valid_adapter?(module()) :: boolean()
  def valid_adapter?(module) when is_atom(module) do
    Code.ensure_loaded?(module) and
    Enum.all?([
      # Study operations
      {:put_study, 1},
      {:get_study, 1},
      {:set_study_status, 2},
      {:list_studies, 0},
      {:delete_study, 1},
      # Trial operations
      {:add_trial, 2},
      {:fetch_trial, 2},
      {:list_trials, 2},
      {:update_trial, 3},
      {:delete_trial, 2},
      # Observation operations
      {:record_observation, 5},
      {:observations_at_rung, 3},
      # Health
      {:health_check, 0}
    ], fn {fun, arity} ->
      function_exported?(module, fun, arity)
    end)
  end
  def valid_adapter?(_), do: false
end