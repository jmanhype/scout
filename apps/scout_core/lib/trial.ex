defmodule Scout.Trial do
  @moduledoc """
  Trial struct representing a single hyperparameter optimization trial.

  A trial is a single execution of the objective function with a specific
  set of hyperparameters. Trials are created, executed, and tracked within
  a study.

  ## Fields

    * `:id` - Unique trial identifier (required)
    * `:study_id` - Parent study identifier (required)
    * `:params` - Hyperparameter values map (required)
    * `:bracket` - Bracket assignment for Hyperband-style pruning (required)
    * `:score` - Final objective value (nil until completed)
    * `:status` - Trial status: `:pending`, `:running`, `:completed`, `:failed`, or `:pruned`
    * `:started_at` - Timestamp when trial started
    * `:finished_at` - Timestamp when trial finished
    * `:rung` - Current rung in pruning schedule
    * `:metrics` - Additional metrics map
    * `:error` - Error message if trial failed
    * `:seed` - Random seed for this trial
    * `:intermediate_values` - Map of step -> intermediate score for pruning
    * `:pruner_state` - Pruner-specific state

  ## Examples

      trial = %Scout.Trial{
        id: "trial-001",
        study_id: "my-study",
        params: %{learning_rate: 0.01, batch_size: 32},
        bracket: 0,
        status: :running,
        started_at: System.system_time(:millisecond)
      }
  """

  @enforce_keys [:id, :study_id, :params, :bracket]
  defstruct [:id, :study_id, :params, :bracket, score: nil, status: :pending,
             started_at: nil, finished_at: nil, rung: 0, metrics: %{}, error: nil, seed: nil,
             intermediate_values: %{}, pruner_state: nil]

  @type status :: :pending | :running | :completed | :failed | :pruned

  @type t :: %__MODULE__{
    id: String.t(),
    study_id: String.t(),
    params: map(),
    bracket: non_neg_integer(),
    score: number() | nil,
    status: status(),
    started_at: integer() | nil,
    finished_at: integer() | nil,
    rung: non_neg_integer(),
    metrics: map(),
    error: String.t() | nil,
    seed: non_neg_integer() | nil,
    intermediate_values: %{non_neg_integer() => number()},
    pruner_state: map() | nil
  }

  @doc """
  Suggest a float value for a hyperparameter.
  """
  def suggest_float(_trial, _param_name, min, max, opts \\ []) do
    if Keyword.get(opts, :log, false) do
      # Log-uniform distribution
      log_min = :math.log(min)
      log_max = :math.log(max)
      log_value = log_min + :rand.uniform() * (log_max - log_min)
      :math.exp(log_value)
    else
      # Uniform distribution
      min + :rand.uniform() * (max - min)
    end
  end
  
  @doc """
  Suggest an integer value for a hyperparameter.
  """
  def suggest_int(_trial, _param_name, min, max) do
    min + :rand.uniform(max - min + 1) - 1
  end
  
  @doc """
  Suggest a categorical value for a hyperparameter.
  """
  def suggest_categorical(_trial, _param_name, choices) do
    Enum.random(choices)
  end
  
  @doc """
  Report an intermediate value for pruning.
  """
  def report(trial, value, step) do
    updated_values = Map.put(trial.intermediate_values || %{}, step, value)
    %{trial | intermediate_values: updated_values}
  end
  
  @doc """
  Check if the trial should be pruned.
  """
  def should_prune?(trial) do
    # Simple implementation - would need to integrate with actual pruner
    trial.status == :pruned
  end
end
