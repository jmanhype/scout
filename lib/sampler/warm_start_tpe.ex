defmodule Scout.Sampler.WarmStartTPE do
  @behaviour Scout.Sampler
  @moduledoc """
  TPE sampler with warm starting capability.
  
  This implementation can leverage trials from previous studies to
  accelerate optimization, similar to transfer learning in machine learning.
  
  Useful for:
  - Resuming interrupted optimization
  - Transfer learning from similar tasks
  - Incremental optimization with new data
  """
  
  def init(opts) do
    base_state = Scout.Sampler.TPE.init(opts)
    
    Map.merge(base_state, %{
      # Previous trials to warm start from
      warm_start_trials: Map.get(opts, :warm_start_trials, []),
      # Weight for previous trials (0.0 to 1.0)
      warm_start_weight: Map.get(opts, :warm_start_weight, 0.5),
      # Whether to adapt previous trials to current space
      adapt_warm_start: Map.get(opts, :adapt_warm_start, true),
      # Source study ID for warm starting
      source_study_id: Map.get(opts, :source_study_id)
    })
  end
  
  def next(space_fun, ix, history, state) do
    # Combine current history with warm start trials
    combined_history = combine_histories(
      history, 
      state.warm_start_trials,
      state.warm_start_weight,
      state.adapt_warm_start,
      space_fun.(ix)
    )
    
    if length(combined_history) < state.min_obs do
      # Not enough data even with warm start, use random
      Scout.Sampler.RandomSearch.next(space_fun, ix, history, state)
    else
      # Use TPE with combined history
      tpe_state = Map.drop(state, [:warm_start_trials, :warm_start_weight, 
                                    :adapt_warm_start, :source_study_id])
      Scout.Sampler.TPE.next(space_fun, ix, combined_history, tpe_state)
    end
  end
  
  # Combine current and warm start histories with weighting
  defp combine_histories(current_history, warm_start_trials, weight, adapt, current_spec) do
    if warm_start_trials == [] do
      current_history
    else
      # Adapt warm start trials to current search space if needed
      adapted_trials = if adapt do
        adapt_trials_to_space(warm_start_trials, current_spec)
      else
        warm_start_trials
      end
      
      # Weight the warm start trials
      weighted_warm_trials = weight_trials(adapted_trials, weight)
      
      # Combine with current history
      weighted_warm_trials ++ current_history
    end
  end
  
  # Adapt trials from a different search space to the current one
  defp adapt_trials_to_space(trials, target_spec) do
    Enum.map(trials, fn trial ->
      adapted_params = adapt_parameters(trial.params, target_spec)
      
      %{trial | params: adapted_params}
    end)
    |> Enum.filter(fn trial -> 
      # Only keep trials that could be successfully adapted
      trial.params != nil
    end)
  end
  
  # Adapt individual parameters to target specification
  defp adapt_parameters(params, target_spec) do
    try do
      Enum.reduce(target_spec, %{}, fn {key, spec}, acc ->
        value = Map.get(params, key)
        
        adapted_value = if value != nil do
          adapt_value(value, spec)
        else
          # Parameter doesn't exist in warm start, sample default
          sample_default(spec)
        end
        
        if adapted_value != nil do
          Map.put(acc, key, adapted_value)
        else
          acc
        end
      end)
    rescue
      _ -> nil
    end
  end
  
  # Adapt a value to match the target specification
  defp adapt_value(value, spec) do
    case spec do
      {:uniform, min, max} when is_number(value) ->
        # Clamp to range
        max(min, min(max, value))
      
      {:log_uniform, min, max} when is_number(value) and value > 0 ->
        # Clamp to range
        max(min, min(max, value))
      
      {:int, min, max} when is_number(value) ->
        # Convert to integer and clamp
        clamped = max(min, min(max, round(value)))
        round(clamped)
      
      {:choice, choices} ->
        # Check if value is in choices
        if value in choices do
          value
        else
          # Try to find closest match
          find_closest_choice(value, choices)
        end
      
      _ ->
        nil
    end
  end
  
  # Find the closest choice for categorical parameters
  defp find_closest_choice(value, choices) do
    # Simple string matching for now
    value_str = to_string(value)
    
    best_match = Enum.max_by(choices, fn choice ->
      choice_str = to_string(choice)
      String.jaro_distance(value_str, choice_str)
    end)
    
    best_match
  end
  
  # Sample a default value for missing parameters
  defp sample_default(spec) do
    case spec do
      {:uniform, min, max} ->
        (min + max) / 2.0
      
      {:log_uniform, min, max} ->
        :math.exp((:math.log(min) + :math.log(max)) / 2.0)
      
      {:int, min, max} ->
        div(min + max, 2)
      
      {:choice, choices} ->
        # Pick the first choice as default
        List.first(choices)
      
      _ ->
        nil
    end
  end
  
  # Apply weighting to warm start trials
  defp weight_trials(trials, weight) do
    Enum.map(trials, fn trial ->
      # Adjust the score based on weight
      # Lower weight means less influence
      adjusted_score = if trial.score != nil do
        # Blend towards mean to reduce influence
        mean_score = calculate_mean_score(trials)
        weight * trial.score + (1 - weight) * mean_score
      else
        trial.score
      end
      
      %{trial | 
        score: adjusted_score
      }
    end)
  end
  
  # Calculate mean score of trials
  defp calculate_mean_score(trials) do
    scores = trials
             |> Enum.map(& &1.score)
             |> Enum.filter(&is_number/1)
    
    if scores == [] do
      0.0
    else
      Enum.sum(scores) / length(scores)
    end
  end
  
  @doc """
  Load trials from a previous study for warm starting.
  """
  def load_warm_start_trials(study_id) do
    # This would typically load from storage
    # For now, return empty list
    []
  end
  
  @doc """
  Create a warm start sampler from a previous study.
  """
  def from_study(source_study_id, opts \\ %{}) do
    warm_trials = load_warm_start_trials(source_study_id)
    
    init(Map.merge(opts, %{
      warm_start_trials: warm_trials,
      source_study_id: source_study_id
    }))
  end
end