defmodule Scout.Pruner.PercentilePruner do
  @moduledoc """
  Prunes trials that perform worse than a specified percentile of previous trials.
  
  Equivalent to Optuna's PercentilePruner. More flexible than MedianPruner,
  allowing you to set any percentile threshold (e.g., 25th, 75th percentile).
  """
  
  @behaviour Scout.Pruner

  # Default implementation for missing callbacks
  def assign_bracket(_trial_index, state), do: {0, state}
  def keep?(_study_id, _trial_id, _bracket, _step, state), do: {true, state}
  
  @default_percentile 25.0
  @default_n_startup_trials 5
  @default_n_warmup_steps 0
  @default_interval_steps 1
  
  def init(opts \\ %{}) do
    %{
      percentile: Map.get(opts, :percentile, @default_percentile),
      n_startup_trials: Map.get(opts, :n_startup_trials, @default_n_startup_trials),
      n_warmup_steps: Map.get(opts, :n_warmup_steps, @default_n_warmup_steps),
      interval_steps: Map.get(opts, :interval_steps, @default_interval_steps)
    }
  end
  
  def should_prune?(study_id, _trial_id, step, value, state) do
    # Validate percentile
    if state.percentile < 0 or state.percentile > 100 do
      raise ArgumentError, "Percentile must be between 0 and 100, got #{state.percentile}"
    end
    
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
            # Calculate percentile threshold
            threshold = calculate_percentile(intermediate_values, state.percentile)
            
            # Prune if worse than percentile (assuming minimization)
            should_prune = value > threshold
            {should_prune, state}
          end
        end
      end
    end
  end
  
  defp get_intermediate_value(trial, step) do
    Map.get(trial.intermediate_values || %{}, step)
  end
  
  defp calculate_percentile(values, percentile) do
    sorted = Enum.sort(values)
    n = length(sorted)
    
    if n == 1 do
      hd(sorted)
    else
      # Calculate position
      k = percentile * (n - 1) / 100.0
      f = :erlang.trunc(k)
      c = :erlang.float(f)
      
      if k == c do
        # Exact position
        Enum.at(sorted, f)
      else
        # Interpolate between two values
        d0 = Enum.at(sorted, f)
        d1 = Enum.at(sorted, f + 1)
        d0 + (d1 - d0) * (k - c)
      end
    end
  end
end