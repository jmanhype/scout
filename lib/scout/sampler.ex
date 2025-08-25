defmodule Scout.Sampler do
  @moduledoc """
  Behaviour for hyperparameter sampling strategies.
  
  All samplers MUST implement this behaviour. Direct function passing is NOT allowed.
  This ensures black-box boundaries and compile-time verification.
  
  ## Contract
  
  - `init/1` - Initialize sampler state with configuration
  - `next/4` - Generate next parameter suggestion based on history
  
  ## Example Implementation
  
      defmodule MyCustomSampler do
        @behaviour Scout.Sampler
        
        @impl Scout.Sampler
        def init(opts) do
          %{seed: opts[:seed] || 0}
        end
        
        @impl Scout.Sampler
        def next(search_space, trial_index, history, state) do
          params = generate_params(search_space, state)
          {params, state}
        end
      end
  """
  
  @typedoc "Search space specification or function returning one"
  @type search_space :: map() | (non_neg_integer() -> map())
  
  @typedoc "Trial index (0-based)"
  @type trial_index :: non_neg_integer()
  
  @typedoc "Historical trials with params and scores"
  @type history :: [map()]
  
  @typedoc "Sampler internal state"
  @type state :: map()
  
  @typedoc "Generated parameters"
  @type params :: map()
  
  @doc """
  Initialize sampler with configuration options.
  
  ## Options
  - `:seed` - Random seed for reproducibility
  - `:gamma` - TPE gamma parameter (fraction for good/bad split)
  - Other sampler-specific options
  
  Returns initial sampler state.
  """
  @callback init(opts :: map()) :: state()
  
  @doc """
  Generate next parameter suggestion.
  
  ## Arguments
  - `search_space` - Parameter specifications (ranges, choices, etc.)
  - `trial_index` - Current trial number (0-based)
  - `history` - List of completed trials with params and scores
  - `state` - Current sampler state
  
  ## Returns
  `{params, new_state}` where:
  - `params` - Map of parameter name to value
  - `new_state` - Updated sampler state
  
  ## Constraints
  - MUST handle empty history (cold start)
  - MUST respect search space bounds
  - MUST be deterministic given same inputs and state
  """
  @callback next(
    search_space :: search_space(),
    trial_index :: trial_index(), 
    history :: history(),
    state :: state()
  ) :: {params :: params(), new_state :: state()}
  
  @doc """
  Validates that a module implements the Scout.Sampler behaviour.
  Raises at compile time if not.
  """
  defmacro __using__(_opts) do
    quote do
      @behaviour Scout.Sampler
    end
  end
  
  @doc """
  Runtime validation that a module implements Scout.Sampler.
  Used by executors to verify sampler modules.
  """
  @spec valid_sampler?(module()) :: boolean()
  def valid_sampler?(module) when is_atom(module) do
    Code.ensure_loaded?(module) and
    function_exported?(module, :init, 1) and
    function_exported?(module, :next, 4)
  end
  def valid_sampler?(_), do: false
end