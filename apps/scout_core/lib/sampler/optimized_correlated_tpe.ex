defmodule Scout.Sampler.OptimizedCorrelatedTpe do
  @moduledoc """
  Optimized multivariate TPE with improved correlation handling.
  
  Improvements:
  1. Better bandwidth selection using Scott's rule
  2. Improved correlation estimation with regularization
  3. More sophisticated copula sampling
  4. Adaptive exploration/exploitation balance
  """
  
  alias Scout.Sampler.RandomSearch
  
  def init(opts) do
    %{
      gamma: Map.get(opts, :gamma, 0.25),
      n_candidates: Map.get(opts, :n_candidates, 24),
      min_obs: Map.get(opts, :min_obs, 10),
      goal: Map.get(opts, :goal, :minimize),
      bandwidth_factor: Map.get(opts, :bandwidth_factor, 1.06),  # Scott's rule
      exploration_rate: Map.get(opts, :exploration_rate, 0.3),
      correlation_threshold: Map.get(opts, :correlation_threshold, 0.2)
    }
  end
  
  def next(space_fun, ix, history, state) do
    if length(history) < state.min_obs do
      RandomSearch.next(space_fun, ix, history, state)
    else
      spec = space_fun.(ix)
      param_keys = Map.keys(spec) |> Enum.sort()
      n_params = length(param_keys)
      
      # Split history with adaptive gamma
      adaptive_gamma = compute_adaptive_gamma(history, state)
      {good_trials, bad_trials} = split_by_performance(history, %{state | gamma: adaptive_gamma})
      
      # Build enhanced copula models
      good_copula = build_enhanced_copula(good_trials, param_keys, spec, state)
      bad_copula = build_enhanced_copula(bad_trials, param_keys, spec, state)
      
      # Adaptive exploration rate based on convergence
      exploration_rate = compute_exploration_rate(history, state)
      
      # Generate diverse candidates
      candidates = generate_diverse_candidates(
        good_copula, 
        param_keys, 
        spec, 
        state.n_candidates,
        exploration_rate
      )
      
      # Enhanced EI selection
      best = select_best_enhanced_ei(
        candidates, 
        good_trials, 
        bad_trials, 
        param_keys, 
        state.bandwidth_factor,
        n_params
      )
      
      {best, state}
    end
  end
  
  defp compute_adaptive_gamma(history, state) do
    # Adjust gamma based on convergence
    n = length(history)
    
    if n < 20 do
      0.25
    else
      # Check convergence by looking at recent improvements
      recent = Enum.take(history, -10)
      recent_scores = Enum.map(recent, & &1.score)
      
      improvement = case state.goal do
        :minimize -> 
          best_recent = Enum.min(recent_scores)
          best_old = history 
                    |> Enum.take(n - 10) 
                    |> Enum.map(& &1.score)
                    |> Enum.min()
          (best_old - best_recent) / abs(best_old + 1.0e-10)
        _ ->
          best_recent = Enum.max(recent_scores)
          best_old = history 
                    |> Enum.take(n - 10)
                    |> Enum.map(& &1.score)
                    |> Enum.max()
          (best_recent - best_old) / abs(best_old + 1.0e-10)
      end
      
      # Less improvement -> tighter gamma (more exploitation)
      cond do
        improvement < 0.01 ->
          0.15
        improvement < 0.05 ->
          0.20
        true ->
          0.25
      end
    end
  end
  
  defp split_by_performance(history, state) do
    sorted = case state.goal do
      :minimize -> Enum.sort_by(history, & &1.score)
      _ -> Enum.sort_by(history, & &1.score, :desc)
    end
    
    n_good = max(1, round(length(sorted) * state.gamma))
    Enum.split(sorted, n_good)
  end
  
  defp build_enhanced_copula(trials, param_keys, spec, state) do
    if length(trials) < 2 do
      nil
    else
      # Convert to uniform marginals with better normalization
      uniform_data = Enum.map(trials, fn trial ->
        Enum.map(param_keys, fn k ->
          val = Map.get(trial.params, k, 0.0) || 0.0
          to_uniform_enhanced(val, spec[k])
        end)
      end)
      
      # Compute regularized correlation matrix
      corr_matrix = compute_regularized_correlation(uniform_data, state.correlation_threshold)
      
      # Compute empirical marginals for better modeling
      marginals = compute_marginals(uniform_data)
      
      %{
        data: uniform_data,
        corr: corr_matrix,
        n: length(param_keys),
        marginals: marginals,
        n_samples: length(trials)
      }
    end
  end
  
  defp to_uniform_enhanced(val, spec_entry) do
    case spec_entry do
      {:uniform, min, max} -> 
        # Clamp and normalize
        clamped = max(min, min(max, val))
        (clamped - min) / (max - min)
        
      {:log_uniform, min, max} ->
        clamped = max(min, min(max, val))
        log_min = :math.log(min)
        log_max = :math.log(max)
        (:math.log(clamped) - log_min) / (log_max - log_min)
        
      {:int, min, max} ->
        clamped = max(min, min(max, round(val)))
        (clamped - min) / (max - min + 1)
        
      _ -> 0.5
    end
  end
  
  defp from_uniform_enhanced(u, spec_entry) do
    # Add small noise to break ties
    u = max(0.001, min(0.999, u))
    
    case spec_entry do
      {:uniform, min, max} -> 
        min + u * (max - min)
        
      {:log_uniform, min, max} ->
        log_min = :math.log(min)
        log_max = :math.log(max)
        :math.exp(log_min + u * (log_max - log_min))
        
      {:int, min, max} ->
        round(min + u * (max - min))
        
      _ -> u
    end
  end
  
  defp compute_regularized_correlation(data, threshold) do
    n = length(hd(data))
    m = length(data)
    
    if m < 3 do
      # Not enough data, return identity
      for i <- 0..(n-1) do
        for j <- 0..(n-1) do
          if i == j, do: 1.0, else: 0.0
        end
      end
    else
      # Compute means
      means = for i <- 0..(n-1) do
        Enum.sum(Enum.map(data, fn row -> Enum.at(row, i) end)) / m
      end
      
      # Compute correlation with regularization
      for i <- 0..(n-1) do
        for j <- 0..(n-1) do
          if i == j do
            1.0
          else
            xi_vals = Enum.map(data, fn row -> Enum.at(row, i) end)
            xj_vals = Enum.map(data, fn row -> Enum.at(row, j) end)
            
            corr = compute_pearson_correlation(
              xi_vals, xj_vals, 
              Enum.at(means, i), Enum.at(means, j),
              m
            )
            
            # Apply threshold to reduce noise
            if abs(corr) < threshold, do: 0.0, else: corr
          end
        end
      end
    end
  end
  
  defp compute_pearson_correlation(x_vals, y_vals, x_mean, y_mean, n) do
    cov = Enum.zip(x_vals, y_vals)
          |> Enum.map(fn {x, y} -> (x - x_mean) * (y - y_mean) end)
          |> Enum.sum()
          |> Kernel./(n - 1)
    
    x_std = :math.sqrt(
      Enum.map(x_vals, fn x -> :math.pow(x - x_mean, 2) end)
      |> Enum.sum()
      |> Kernel./(n - 1)
    )
    
    y_std = :math.sqrt(
      Enum.map(y_vals, fn y -> :math.pow(y - y_mean, 2) end)
      |> Enum.sum()
      |> Kernel./(n - 1)
    )
    
    if x_std * y_std > 1.0e-10 do
      max(-1.0, min(1.0, cov / (x_std * y_std)))
    else
      0.0
    end
  end
  
  defp compute_marginals(data) do
    n = length(hd(data))
    
    for i <- 0..(n-1) do
      vals = Enum.map(data, fn row -> Enum.at(row, i) end)
      %{
        mean: Enum.sum(vals) / length(vals),
        std: compute_std(vals),
        min: Enum.min(vals),
        max: Enum.max(vals)
      }
    end
  end
  
  defp compute_std(vals) do
    mean = Enum.sum(vals) / length(vals)
    variance = Enum.map(vals, fn v -> :math.pow(v - mean, 2) end)
               |> Enum.sum()
               |> Kernel./(length(vals))
    :math.sqrt(variance)
  end
  
  defp compute_exploration_rate(history, state) do
    n = length(history)
    
    if n < 30 do
      state.exploration_rate
    else
      # Reduce exploration as we converge
      recent_improvement = compute_recent_improvement(history, state)
      
      cond do
        recent_improvement < 0.01 ->
          max(0.1, state.exploration_rate * 0.5)
        recent_improvement < 0.05 ->
          max(0.15, state.exploration_rate * 0.75)
        true ->
          state.exploration_rate
      end
    end
  end
  
  defp compute_recent_improvement(history, state) do
    n = length(history)
    window = min(10, div(n, 3))
    
    recent = Enum.take(history, -window)
    old = Enum.slice(history, 0, n - window)
    
    if old == [] do
      1.0
    else
      recent_best = case state.goal do
        :minimize -> recent |> Enum.map(& &1.score) |> Enum.min()
        _ -> recent |> Enum.map(& &1.score) |> Enum.max()
      end
      
      old_best = case state.goal do
        :minimize -> old |> Enum.map(& &1.score) |> Enum.min()
        _ -> old |> Enum.map(& &1.score) |> Enum.max()
      end
      
      abs((recent_best - old_best) / (abs(old_best) + 1.0e-10))
    end
  end
  
  defp generate_diverse_candidates(copula, param_keys, spec, n_candidates, exploration_rate) do
    for i <- 1..n_candidates do
      cond do
        # Pure exploration
        i <= round(n_candidates * exploration_rate) ->
          Scout.SearchSpace.sample(spec)
          
        # Copula sampling if available
        copula != nil and copula.n_samples >= 3 ->
          sample_from_enhanced_copula(copula, param_keys, spec, i)
          
        # Fallback to random
        true ->
          Scout.SearchSpace.sample(spec)
      end
    end
  end
  
  defp sample_from_enhanced_copula(copula, param_keys, spec, seed) do
    n = copula.n
    
    # Use seed for deterministic behavior
    :rand.seed(:exsss, {seed, seed, seed})
    
    # Generate correlated normal samples
    z = List.duplicate(0, n) |> Enum.map(fn _ -> :rand.normal() end)
    
    # Apply correlation structure using simplified Cholesky
    correlated = apply_correlation(z, copula.corr)
    
    # Transform to uniform via normal CDF
    uniform = Enum.map(correlated, fn z_val ->
      # Standard normal CDF
      0.5 * (1 + :math.erf(z_val / :math.sqrt(2)))
    end)
    
    # Apply marginal transformations
    adjusted = Enum.zip(uniform, copula.marginals)
               |> Enum.map(fn {u, marginal} ->
                 # Adjust based on empirical distribution
                 if marginal.std > 0 do
                   # Stretch/compress based on observed variance
                   u_adjusted = marginal.mean + (u - 0.5) * 2 * marginal.std
                   max(0.0, min(1.0, u_adjusted))
                 else
                   u
                 end
               end)
    
    # Transform back to parameter space
    Enum.zip(param_keys, adjusted)
    |> Map.new(fn {k, u} ->
      {k, from_uniform_enhanced(u, spec[k])}
    end)
  end
  
  defp apply_correlation(z, corr_matrix) do
    n = length(z)
    
    if n == 2 do
      # Special case for 2D with exact correlation
      r = corr_matrix |> Enum.at(0) |> Enum.at(1)
      z1 = Enum.at(z, 0)
      z2 = Enum.at(z, 1)
      
      # Apply correlation
      [z1, r * z1 + :math.sqrt(max(0, 1 - r*r)) * z2]
    else
      # For higher dimensions, use simplified approach
      # Apply average correlation to maintain some dependence
      avg_corr = compute_avg_correlation(corr_matrix)
      
      Enum.map(z, fn zi ->
        # Mix with average of other components
        others_avg = (Enum.sum(z) - zi) / (n - 1)
        (1 - abs(avg_corr)) * zi + avg_corr * others_avg
      end)
    end
  end
  
  defp compute_avg_correlation(corr_matrix) do
    n = length(corr_matrix)
    
    # Average off-diagonal elements
    sum = for i <- 0..(n-1), j <- 0..(n-1), i != j do
      corr_matrix |> Enum.at(i) |> Enum.at(j)
    end
    |> Enum.sum()
    
    sum / (n * (n - 1))
  end
  
  defp select_best_enhanced_ei(candidates, good_trials, bad_trials, param_keys, bandwidth, n_params) do
    # Adaptive bandwidth based on dimensionality
    adaptive_bandwidth = bandwidth * :math.pow(n_params, 1/4)
    
    scored = Enum.map(candidates, fn cand ->
      good_score = enhanced_kde_likelihood(cand, good_trials, param_keys, adaptive_bandwidth)
      bad_score = enhanced_kde_likelihood(cand, bad_trials, param_keys, adaptive_bandwidth)
      
      # Enhanced EI with uncertainty bonus
      n_good = length(good_trials)
      n_bad = length(bad_trials)
      
      uncertainty_bonus = 1.0 / :math.sqrt(n_good + n_bad + 1)
      
      ei = if bad_score > 1.0e-10 do
        (good_score / bad_score) * (1 + uncertainty_bonus)
      else
        good_score * (1 + 2 * uncertainty_bonus)
      end
      
      {cand, ei}
    end)
    
    {best, _} = Enum.max_by(scored, fn {_, score} -> score end)
    best
  end
  
  defp enhanced_kde_likelihood(params, trials, param_keys, bandwidth) do
    if trials == [] do
      1.0e-10
    else
      scores = Enum.map(trials, fn trial ->
        # Compute normalized distance
        dist_sq = Enum.reduce(param_keys, 0.0, fn k, acc ->
          v1 = params[k] || 0.0
          v2 = Map.get(trial.params, k, 0.0) || 0.0
          
          # Scale-invariant distance
          diff = abs(v1 - v2)
          # Estimate scale from parameter range
          scale = estimate_scale(k, trials)
          
          if scale > 0 do
            acc + :math.pow(diff / scale, 2)
          else
            acc
          end
        end)
        
        # Gaussian kernel with bandwidth
        :math.exp(-dist_sq / (2 * bandwidth * bandwidth))
      end)
      
      # Average with minimum threshold
      max(1.0e-10, Enum.sum(scores) / length(scores))
    end
  end
  
  defp estimate_scale(param_key, trials) do
    values = Enum.map(trials, fn t -> 
      Map.get(t.params, param_key, 0.0) || 0.0
    end)
    
    if length(values) > 1 do
      min_val = Enum.min(values)
      max_val = Enum.max(values)
      
      range = max_val - min_val
      if range > 0, do: range, else: 1.0
    else
      1.0
    end
  end
end