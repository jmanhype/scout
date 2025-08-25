defmodule Scout.Trial do
  @enforce_keys [:id, :study_id, :params, :bracket]
  defstruct [:id, :study_id, :params, :bracket, score: nil, status: :pending,
             started_at: nil, finished_at: nil, rung: 0, metrics: %{}, error: nil, seed: nil,
             intermediate_values: %{}, pruner_state: nil]
  
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
