defmodule Scout.Pruner.PatientPruner do
  @moduledoc """
  Prunes trials that haven't improved for a specified number of steps.
  
  Equivalent to Optuna's PatientPruner. Allows trials to continue even if they're
  temporarily underperforming, only pruning after sustained lack of improvement.
  """
  
  @behaviour Scout.Pruner

  # Default implementation for missing callbacks
  def assign_bracket(_trial_index, state), do: {0, state}
  def keep?(_study_id, _trial_id, _bracket, _step, state), do: {true, state}
  
  @default_patience 10
  @default_min_delta 0.0
  
  def init(opts \\ %{}) do
    %{
      patience: Map.get(opts, :patience, @default_patience),
      min_delta: Map.get(opts, :min_delta, @default_min_delta),
      best_values: %{},  # Track best value per trial
      steps_without_improvement: %{}  # Track patience counter per trial
    }
  end
  
  def should_prune?(_study_id, trial_id, _step, value, state) do
    # Get current best value for this trial
    best_value = Map.get(state.best_values, trial_id, :infinity)
    
    # Check if this is an improvement (assuming minimization)
    improved = value < (best_value - state.min_delta)
    
    # Update state
    {new_best, new_counter} = if improved do
      # New best value found, reset counter
      {value, 0}
    else
      # No improvement, increment counter
      counter = Map.get(state.steps_without_improvement, trial_id, 0) + 1
      {best_value, counter}
    end
    
    # Update state maps
    new_state = %{state |
      best_values: Map.put(state.best_values, trial_id, new_best),
      steps_without_improvement: Map.put(state.steps_without_improvement, trial_id, new_counter)
    }
    
    # Prune if patience exceeded
    should_prune = new_counter >= state.patience
    
    # Clean up state if trial is being pruned
    final_state = if should_prune do
      %{new_state |
        best_values: Map.delete(new_state.best_values, trial_id),
        steps_without_improvement: Map.delete(new_state.steps_without_improvement, trial_id)
      }
    else
      new_state
    end
    
    {should_prune, final_state}
  end
  
  @doc """
  Cleans up state for a completed trial.
  """
  def cleanup_trial(state, trial_id) do
    %{state |
      best_values: Map.delete(state.best_values, trial_id),
      steps_without_improvement: Map.delete(state.steps_without_improvement, trial_id)
    }
  end
  
  @doc """
  Gets the current patience counter for a trial.
  """
  def get_patience_counter(state, trial_id) do
    Map.get(state.steps_without_improvement, trial_id, 0)
  end
  
  @doc """
  Gets the best value seen so far for a trial.
  """
  def get_best_value(state, trial_id) do
    Map.get(state.best_values, trial_id)
  end
end