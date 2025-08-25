defmodule Scout.Sampler.CmaesSimple do
  @moduledoc """
  Simple CMA-ES-inspired sampler for continuous optimization.
  Much simpler than full CMA-ES but captures the key ideas:
  - Population-based search
  - Adaptive step size
  - Learning from best performers
  """
  
  def init(opts) do
    %{
      population_size: Map.get(opts, :population_size, 10),
      elite_ratio: Map.get(opts, :elite_ratio, 0.5),
      goal: Map.get(opts, :goal, :minimize),
      step_size: Map.get(opts, :step_size, 1.0),
      momentum: Map.get(opts, :momentum, 0.9),
      min_obs: Map.get(opts, :min_obs, 5),
      # Track mean and covariance
      mean: %{},
      velocity: %{},
      generation: 0
    }
  end
  
  def next(space_fun, ix, history, state) do
    spec = space_fun.(ix)
    
    # Use random sampling for initial population
    if length(history) < state.min_obs do
      params = Scout.SearchSpace.sample(spec)
      {params, state}
    else
      # Extract parameter keys and ranges
      param_keys = Map.keys(spec)
      ranges = extract_ranges(spec)
      
      # Get elite samples from history
      elite = get_elite(history, state)
      
      # Update distribution mean based on elite
      new_mean = if elite == [] do
        # Initialize mean at center of search space
        Map.new(param_keys, fn k ->
          {min_val, max_val} = Map.get(ranges, k, {0.0, 1.0})
          {k, (min_val + max_val) / 2.0}
        end)
      else
        compute_mean(elite, param_keys)
      end
      
      # Update velocity (momentum)
      new_velocity = Map.new(param_keys, fn k ->
        old_v = Map.get(state.velocity, k, 0.0)
        old_m = Map.get(state.mean, k, Map.get(new_mean, k))
        new_m = Map.get(new_mean, k)
        {k, state.momentum * old_v + (1 - state.momentum) * (new_m - old_m)}
      end)
      
      # Sample around mean with adaptive step size
      params = sample_from_distribution(new_mean, new_velocity, state.step_size, spec, ranges)
      
      # Adaptive step size based on success rate
      new_step_size = adapt_step_size(state.step_size, elite, history, state.goal)
      
      # Update state
      new_state = %{state | 
        mean: new_mean,
        velocity: new_velocity,
        step_size: new_step_size,
        generation: state.generation + 1
      }
      
      {params, new_state}
    end
  end
  
  defp extract_ranges(spec) do
    Map.new(spec, fn {k, v} ->
      case v do
        {:uniform, min, max} -> {k, {min, max}}
        {:log_uniform, min, max} -> {k, {:math.log(min), :math.log(max)}}
        {:int, min, max} -> {k, {min, max}}
        _ -> {k, {0.0, 1.0}}
      end
    end)
  end
  
  defp get_elite(history, state) do
    n_elite = max(1, round(length(history) * state.elite_ratio))
    
    sorted = case state.goal do
      :minimize -> Enum.sort_by(history, & &1.score)
      _ -> Enum.sort_by(history, & &1.score, :desc)
    end
    
    Enum.take(sorted, n_elite)
  end
  
  defp compute_mean(elite, param_keys) do
    n = length(elite)
    
    Map.new(param_keys, fn k ->
      sum = Enum.reduce(elite, 0.0, fn trial, acc ->
        acc + (Map.get(trial.params, k, 0.0) || 0.0)
      end)
      {k, sum / n}
    end)
  end
  
  defp sample_from_distribution(mean, velocity, step_size, spec, ranges) do
    Map.new(spec, fn {k, type} ->
      mean_val = Map.get(mean, k, 0.0)
      vel_val = Map.get(velocity, k, 0.0)
      {min_val, max_val} = Map.get(ranges, k, {0.0, 1.0})
      
      # Sample with momentum and noise
      base = mean_val + vel_val * step_size
      noise = :rand.normal() * step_size * abs(max_val - min_val) * 0.1
      raw_val = base + noise
      
      # Apply type constraints
      val = case type do
        {:uniform, min, max} ->
          max(min, min(max, raw_val))
        {:log_uniform, min, max} ->
          log_val = max(:math.log(min), min(:math.log(max), raw_val))
          :math.exp(log_val)
        {:int, min, max} ->
          round(max(min, min(max, raw_val)))
        _ ->
          raw_val
      end
      
      {k, val}
    end)
  end
  
  defp adapt_step_size(current_step, elite, history, goal) do
    # Simple 1/5 success rule adaptation
    if length(history) < 10 do
      current_step
    else
      recent = Enum.take(history, -10)
      recent_best = case goal do
        :minimize -> Enum.min_by(recent, & &1.score)
        _ -> Enum.max_by(recent, & &1.score)
      end
      
      # Check if recent best is better than historical average
      avg_score = Enum.sum(Enum.map(history, & &1.score)) / length(history)
      
      improvement = case goal do
        :minimize -> recent_best.score < avg_score * 0.8
        _ -> recent_best.score > avg_score * 1.2
      end
      
      if improvement do
        # Good progress, increase step size
        min(current_step * 1.1, 2.0)
      else
        # Poor progress, decrease step size
        max(current_step * 0.9, 0.1)
      end
    end
  end
end