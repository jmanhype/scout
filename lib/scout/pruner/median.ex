defmodule Scout.Pruner.MedianPruner do
  @moduledoc """
  Prunes trials that perform worse than the median of previous trials at the same step.
  
  Equivalent to Optuna's MedianPruner. Effective for early stopping of unpromising trials.
  """
  
  @behaviour Scout.Pruner

  # Default implementation for missing callbacks
  def assign_bracket(_trial_index, state), do: {0, state}
  def keep?(_study_id, _trial_id, _bracket, _step, state), do: {true, state}
  
  @default_n_startup_trials 5
  @default_n_warmup_steps 0
  @default_interval_steps 1
  
  def init(opts \\ %{}) do
    %{
      n_startup_trials: Map.get(opts, :n_startup_trials, @default_n_startup_trials),
      n_warmup_steps: Map.get(opts, :n_warmup_steps, @default_n_warmup_steps),
      interval_steps: Map.get(opts, :interval_steps, @default_interval_steps)
    }
  end
  
  def should_prune?(study_id, _trial_id, step, value, state) do
    # Don't prune during warmup steps
    if step < state.n_warmup_steps do
      {false, state}
    else
      # Only prune at interval steps
      if rem(step - state.n_warmup_steps, state.interval_steps) != 0 do
        {false, state}
      else
        # Get completed trials
        completed_trials = Scout.Store.list_trials(study_id)
        |> Enum.filter(&(&1.status == :completed))
        
        # Don't prune if not enough startup trials
        if length(completed_trials) < state.n_startup_trials do
          {false, state}
        else
          # Get intermediate values at this step
          intermediate_values = completed_trials
          |> Enum.map(&get_intermediate_value(&1, step))
          |> Enum.reject(&is_nil/1)
          
          if length(intermediate_values) == 0 do
            {false, state}
          else
            # Calculate median
            median = calculate_median(intermediate_values)
            
            # Prune if worse than median (assuming minimization)
            should_prune = value > median
            {should_prune, state}
          end
        end
      end
    end
  end
  
  defp get_intermediate_value(trial, step) do
    Map.get(trial.intermediate_values || %{}, step)
  end
  
  defp calculate_median(values) do
    sorted = Enum.sort(values)
    len = length(sorted)
    
    if rem(len, 2) == 1 do
      Enum.at(sorted, div(len, 2))
    else
      mid = div(len, 2)
      (Enum.at(sorted, mid - 1) + Enum.at(sorted, mid)) / 2
    end
  end
end