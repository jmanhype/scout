defmodule Scout.Sampler.MultivariateTpe do
  @moduledoc """
  Multivariate TPE that models correlations between parameters.
  Key improvement: samples all parameters together instead of independently.
  """
  
  alias Scout.Sampler.RandomSearch
  
  def init(opts) do
    %{
      gamma: Map.get(opts, :gamma, 0.25),
      n_candidates: Map.get(opts, :n_candidates, 24),
      min_obs: Map.get(opts, :min_obs, 10),
      goal: Map.get(opts, :goal, :maximize),
      correlation_threshold: Map.get(opts, :correlation_threshold, 0.3)
    }
  end
  
  def next(space_fun, ix, history, state) do
    if length(history) < state.min_obs do
      RandomSearch.next(space_fun, ix, history, state)
    else
      spec = space_fun.(ix)
      param_keys = Map.keys(spec)
      
      # Split history into good and bad
      {good_trials, bad_trials} = split_trials(history, state)
      
      # Generate candidates using multivariate sampling
      candidates = generate_multivariate_candidates(
        spec, 
        param_keys, 
        good_trials, 
        bad_trials, 
        state.n_candidates
      )
      
      # Score candidates using multivariate EI
      best_candidate = select_best_candidate(
        candidates, 
        param_keys, 
        good_trials, 
        bad_trials
      )
      
      {best_candidate, state}
    end
  end
  
  defp split_trials(history, state) do
    sorted = case state.goal do
      :minimize -> Enum.sort_by(history, & &1.score)
      _ -> Enum.sort_by(history, & &1.score, :desc)
    end
    
    n_good = max(1, round(length(sorted) * state.gamma))
    Enum.split(sorted, n_good)
  end
  
  defp generate_multivariate_candidates(spec, param_keys, good_trials, bad_trials, n_candidates) do
    # Compute correlation matrix from good trials
    correlations = compute_correlations(param_keys, good_trials)
    
    # Generate candidates
    Enum.map(1..n_candidates, fn _ ->
      if :rand.uniform() < 0.5 and length(good_trials) > 0 do
        # Sample from good distribution with correlations
        sample_from_correlated_distribution(spec, param_keys, good_trials, correlations)
      else
        # Random exploration
        Scout.SearchSpace.sample(spec)
      end
    end)
  end
  
  defp compute_correlations(param_keys, trials) do
    if length(trials) < 3 do
      # Not enough data for correlations
      %{}
    else
      # Simplified correlation: track which parameters tend to be high/low together
      pairs = for k1 <- param_keys, k2 <- param_keys, k1 < k2, do: {k1, k2}
      
      Map.new(pairs, fn {k1, k2} ->
        values1 = Enum.map(trials, fn t -> Map.get(t.params, k1, 0.0) || 0.0 end)
        values2 = Enum.map(trials, fn t -> Map.get(t.params, k2, 0.0) || 0.0 end)
        
        # Simple correlation measure
        corr = estimate_correlation(values1, values2)
        {{k1, k2}, corr}
      end)
    end
  end
  
  defp estimate_correlation(values1, values2) do
    n = length(values1)
    mean1 = Enum.sum(values1) / n
    mean2 = Enum.sum(values2) / n
    
    # Compute covariance
    cov = Enum.zip(values1, values2)
          |> Enum.map(fn {v1, v2} -> (v1 - mean1) * (v2 - mean2) end)
          |> Enum.sum()
          |> Kernel./(n)
    
    # Compute standard deviations
    std1 = :math.sqrt(Enum.sum(Enum.map(values1, fn v -> :math.pow(v - mean1, 2) end)) / n)
    std2 = :math.sqrt(Enum.sum(Enum.map(values2, fn v -> :math.pow(v - mean2, 2) end)) / n)
    
    if std1 * std2 > 0 do
      cov / (std1 * std2)
    else
      0.0
    end
  end
  
  defp sample_from_correlated_distribution(spec, param_keys, good_trials, correlations) do
    # Pick a good trial as base
    base_trial = Enum.random(good_trials)
    base_params = base_trial.params
    
    # Generate new params with correlations in mind
    Map.new(param_keys, fn k ->
      base_val = Map.get(base_params, k, 0.0) || 0.0
      
      # Add correlated noise
      noise = :rand.normal() * 0.3
      
      # Adjust based on correlations with other parameters
      corr_adjustment = Enum.reduce(param_keys, 0.0, fn other_k, acc ->
        if k != other_k do
          pair = if k < other_k, do: {k, other_k}, else: {other_k, k}
          corr = Map.get(correlations, pair, 0.0)
          
          other_base = Map.get(base_params, other_k, 0.0) || 0.0
          other_noise = :rand.normal() * 0.1
          
          acc + corr * other_noise * 0.5
        else
          acc
        end
      end)
      
      new_val = base_val + noise + corr_adjustment
      
      # Apply bounds from spec
      bounded_val = case Map.get(spec, k) do
        {:uniform, min, max} -> max(min, min(max, new_val))
        {:log_uniform, min, max} -> 
          log_val = max(:math.log(min), min(:math.log(max), new_val))
          :math.exp(log_val)
        {:int, min, max} -> round(max(min, min(max, new_val)))
        _ -> new_val
      end
      
      {k, bounded_val}
    end)
  end
  
  defp select_best_candidate(candidates, param_keys, good_trials, bad_trials) do
    # Score each candidate using multivariate EI
    scored = Enum.map(candidates, fn cand ->
      score = multivariate_ei_score(cand, param_keys, good_trials, bad_trials)
      {cand, score}
    end)
    
    # Select best
    {best, _} = Enum.max_by(scored, fn {_, score} -> score end)
    best
  end
  
  defp multivariate_ei_score(candidate, param_keys, good_trials, bad_trials) do
    # Simplified multivariate EI: product of good/bad likelihood ratios
    # with correlation bonus
    
    good_likelihood = compute_multivariate_likelihood(candidate, param_keys, good_trials)
    bad_likelihood = compute_multivariate_likelihood(candidate, param_keys, bad_trials)
    
    # Avoid division by zero
    good_likelihood = max(good_likelihood, 1.0e-10)
    bad_likelihood = max(bad_likelihood, 1.0e-10)
    
    :math.log(good_likelihood / bad_likelihood)
  end
  
  defp compute_multivariate_likelihood(candidate, param_keys, trials) do
    if trials == [] do
      1.0e-10
    else
      # Compute likelihood as average similarity to trials
      similarities = Enum.map(trials, fn trial ->
        compute_similarity(candidate, trial.params, param_keys)
      end)
      
      Enum.sum(similarities) / length(similarities)
    end
  end
  
  defp compute_similarity(params1, params2, param_keys) do
    # Gaussian kernel similarity
    squared_distances = Enum.map(param_keys, fn k ->
      v1 = Map.get(params1, k, 0.0) || 0.0
      v2 = Map.get(params2, k, 0.0) || 0.0
      :math.pow(v1 - v2, 2)
    end)
    
    total_distance = Enum.sum(squared_distances)
    bandwidth = 1.0  # Could be adaptive
    
    :math.exp(-total_distance / (2 * bandwidth * bandwidth))
  end
end