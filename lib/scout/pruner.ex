defmodule Scout.Pruner do
  @moduledoc """
  Behaviour for early stopping and trial pruning strategies.
  
  All pruners MUST implement this behaviour. Direct function passing is NOT allowed.
  This ensures black-box boundaries and compile-time verification.
  
  ## Contract
  
  - `init/1` - Initialize pruner state
  - `assign_bracket/2` - Assign trial to bracket (for multi-armed strategies)
  - `keep?/5` - Decide whether to continue or prune a trial
  
  ## Example Implementation
  
      defmodule MyPruner do
        @behaviour Scout.Pruner
        
        @impl Scout.Pruner
        def init(opts) do
          %{min_trials: opts[:min_trials] || 5}
        end
        
        @impl Scout.Pruner
        def assign_bracket(_trial_index, state) do
          {0, state}  # Single bracket
        end
        
        @impl Scout.Pruner
        def keep?(_trial_id, scores, _rung, _ctx, state) do
          {length(scores) < state.min_trials, state}
        end
      end
  """
  
  @typedoc "Pruner internal state"
  @type state :: map()
  
  @typedoc "Trial identifier"
  @type trial_id :: binary()
  
  @typedoc "Trial index (0-based)"
  @type trial_index :: non_neg_integer()
  
  @typedoc "Bracket identifier for multi-armed bandit strategies"
  @type bracket :: non_neg_integer()
  
  @typedoc "Rung/checkpoint in the pruning schedule"
  @type rung :: non_neg_integer()
  
  @typedoc "Scores collected so far for this trial"
  @type scores :: [number()]
  
  @typedoc "Execution context"
  @type context :: %{
    study_id: binary(),
    goal: :maximize | :minimize,
    bracket: bracket()
  }
  
  @doc """
  Initialize pruner with configuration options.
  
  ## Options
  - `:min_resource` - Minimum iterations before pruning
  - `:max_resource` - Maximum iterations per trial  
  - `:reduction_factor` - Resource reduction between rungs
  - `:brackets` - Number of brackets (Hyperband)
  - Other pruner-specific options
  
  Returns initial pruner state.
  """
  @callback init(opts :: map()) :: state()
  
  @doc """
  Assign a trial to a bracket.
  
  Used by multi-armed bandit strategies like Hyperband to distribute
  trials across different resource allocation strategies.
  
  ## Arguments
  - `trial_index` - Current trial number (0-based)
  - `state` - Current pruner state
  
  ## Returns
  `{bracket, new_state}` where:
  - `bracket` - Bracket assignment (0-based)
  - `new_state` - Updated pruner state
  """
  @callback assign_bracket(
    trial_index :: trial_index(),
    state :: state()
  ) :: {bracket :: bracket(), new_state :: state()}
  
  @doc """
  Decide whether to continue or prune a trial.
  
  ## Arguments
  - `trial_id` - Unique trial identifier
  - `scores_so_far` - Scores collected at checkpoints
  - `rung` - Current checkpoint/rung
  - `context` - Execution context with study info
  - `state` - Current pruner state
  
  ## Returns
  `{keep?, new_state}` where:
  - `keep?` - true to continue, false to prune
  - `new_state` - Updated pruner state
  
  ## Constraints
  - MUST handle single-score trials
  - MUST respect study goal (maximize/minimize)
  - SHOULD use deterministic pruning given same inputs
  """
  @callback keep?(
    trial_id :: trial_id(),
    scores_so_far :: scores(),
    rung :: rung(),
    context :: context(),
    state :: state()
  ) :: {keep? :: boolean(), new_state :: state()}
  
  @doc """
  Runtime validation that a module implements Scout.Pruner.
  Used by executors to verify pruner modules.
  """
  @spec valid_pruner?(module()) :: boolean()
  def valid_pruner?(module) when is_atom(module) do
    Code.ensure_loaded?(module) and
    function_exported?(module, :init, 1) and
    function_exported?(module, :assign_bracket, 2) and
    function_exported?(module, :keep?, 5)
  end
  def valid_pruner?(_), do: false
end