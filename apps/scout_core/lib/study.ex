defmodule Scout.Study do
  @moduledoc """
  Study configuration struct for Scout hyperparameter optimization.

  A study represents a complete optimization experiment, including:
  - Search space definition
  - Objective function to optimize
  - Sampling strategy (TPE, Random, CMA-ES, etc.)
  - Optional pruning strategy
  - Execution parameters (parallelism, max trials)

  ## Fields

    * `:id` - Unique study identifier (required)
    * `:goal` - Optimization goal: `:minimize` or `:maximize` (required)
    * `:max_trials` - Maximum number of trials to run (required)
    * `:parallelism` - Number of concurrent trials (required)
    * `:search_space` - Function `(trial_index -> params_spec)` or static map (required)
    * `:objective` - Function `(params -> score)` or `(params, report_fn -> score)` (required)
    * `:sampler` - Sampler module (e.g., `Scout.Sampler.TPE`)
    * `:sampler_opts` - Options map for sampler initialization
    * `:pruner` - Optional pruner module (e.g., `Scout.Pruner.MedianPruner`)
    * `:pruner_opts` - Options map for pruner initialization
    * `:executor` - Optional executor module (defaults to iterative)
    * `:seed` - Random seed for reproducibility
    * `:metadata` - Additional metadata map

  ## Examples

      # Minimize a quadratic function
      study = %Scout.Study{
        id: "quadratic-study",
        goal: :minimize,
        max_trials: 100,
        parallelism: 4,
        search_space: fn _ix ->
          %{x: {:uniform, -5, 5}, y: {:uniform, -5, 5}}
        end,
        objective: fn params ->
          (params.x - 2) ** 2 + (params.y - 3) ** 2
        end,
        sampler: Scout.Sampler.TPE,
        sampler_opts: %{seed: 42}
      }

      {:ok, result} = Scout.run(study)
  """

  @enforce_keys [:id, :goal, :max_trials, :parallelism, :search_space, :objective]
  defstruct [:id, :goal, :max_trials, :parallelism,
             :sampler, :sampler_opts, :pruner, :pruner_opts,
             :search_space, :objective, :executor,
             seed: nil, metadata: %{}]

  @type search_space_fn :: (non_neg_integer() -> map())
  @type objective_fn :: (map() -> number()) | (map(), function() -> number())

  @type t :: %__MODULE__{
    id: String.t(),
    goal: :minimize | :maximize,
    max_trials: pos_integer(),
    parallelism: pos_integer(),
    search_space: search_space_fn() | map(),
    objective: objective_fn(),
    sampler: module() | nil,
    sampler_opts: map() | nil,
    pruner: module() | nil,
    pruner_opts: map() | nil,
    executor: module() | nil,
    seed: non_neg_integer() | nil,
    metadata: map()
  }

  @doc """
  Optimize a study with an objective function (like optuna study.optimize).
  """
  def optimize(study, objective, opts \\ []) when is_map(study) and is_function(objective) do
    # Convert the study map to parameters for Scout.Easy.optimize
    n_trials = Keyword.get(opts, :n_trials, 10)
    direction = study[:direction] || study["direction"] || :minimize
    sampler = study[:sampler] || study["sampler"] || :random
    
    # Create a simple search space for the objective - this is a placeholder
    # In a real implementation, this would be derived from the study or passed explicitly
    search_space = %{x: {:uniform, -10, 10}}
    
    # Use Scout.Easy.optimize to run the optimization
    Scout.Easy.optimize(objective, search_space,
      n_trials: n_trials,
      direction: direction,
      sampler: sampler,
      study_name: study[:name] || study[:study_name] || "unknown_study"
    )
  end
end
