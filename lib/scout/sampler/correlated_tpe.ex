defmodule Scout.Sampler.CorrelatedTpe do
  @moduledoc """
  Simplified multivariate TPE that handles parameter correlations.
  
  Key approach:
  1. Use copula-based approach to model correlations
  2. Sample from joint distribution using Gaussian copula
  3. Transform marginals back to original space
  """
  
  alias Scout.Sampler.RandomSearch
  
  def init(opts) do
    %{
      gamma: Map.get(opts, :gamma, 0.25),
      n_candidates: Map.get(opts, :n_candidates, 24),
      min_obs: Map.get(opts, :min_obs, 10),
      goal: Map.get(opts, :goal, :minimize),
      bandwidth_factor: Map.get(opts, :bandwidth_factor, 1.0)
    }
  end
  
  def next(space_fun, ix, history, state) do
    if length(history) < state.min_obs do
      RandomSearch.next(space_fun, ix, history, state)
    else
      spec = space_fun.(ix)
      param_keys = Map.keys(spec) |> Enum.sort()
      
      # Split history
      {good_trials, bad_trials} = split_by_performance(history, state)
      
      # Build copula model from good trials
      good_copula = build_copula_model(good_trials, param_keys, spec)
      bad_copula = build_copula_model(bad_trials, param_keys, spec)
      
      # Generate candidates
      candidates = for _ <- 1..state.n_candidates do
        if :rand.uniform() < 0.7 and good_copula != nil do
          sample_from_copula(good_copula, param_keys, spec)
        else
          Scout.SearchSpace.sample(spec)
        end
      end
      
      # Score using EI
      best = select_best_ei(candidates, good_trials, bad_trials, param_keys, state.bandwidth_factor)
      
      {best, state}
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
  
  defp build_copula_model(trials, param_keys, spec) do
    if length(trials) < 2 do
      nil
    else
      # Convert to uniform marginals
      uniform_data = Enum.map(trials, fn trial ->
        Enum.map(param_keys, fn k ->
          val = Map.get(trial.params, k, 0.0) || 0.0
          to_uniform(val, spec[k])
        end)
      end)
      
      # Compute correlation matrix
      corr_matrix = compute_correlation_matrix(uniform_data)
      
      %{
        data: uniform_data,
        corr: corr_matrix,
        n: length(param_keys)
      }
    end
  end
  
  defp to_uniform(val, spec_entry) do
    case spec_entry do
      {:uniform, min, max} -> 
        (val - min) / (max - min)
      {:log_uniform, min, max} ->
        log_min = :math.log(min)
        log_max = :math.log(max)
        (:math.log(val) - log_min) / (log_max - log_min)
      {:int, min, max} ->
        (val - min) / (max - min + 1)
      _ -> 0.5
    end
  end
  
  defp from_uniform(u, spec_entry) do
    u = max(0.0, min(1.0, u))
    
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
  
  defp compute_correlation_matrix(data) do
    n = length(hd(data))
    m = length(data)
    
    # Compute means
    means = for i <- 0..(n-1) do
      Enum.sum(Enum.map(data, fn row -> Enum.at(row, i) end)) / m
    end
    
    # Compute correlation matrix
    for i <- 0..(n-1) do
      for j <- 0..(n-1) do
        if i == j do
          1.0
        else
          # Compute correlation between dimensions i and j
          xi_vals = Enum.map(data, fn row -> Enum.at(row, i) end)
          xj_vals = Enum.map(data, fn row -> Enum.at(row, j) end)
          
          xi_mean = Enum.at(means, i)
          xj_mean = Enum.at(means, j)
          
          cov = Enum.zip(xi_vals, xj_vals)
                |> Enum.map(fn {xi, xj} -> (xi - xi_mean) * (xj - xj_mean) end)
                |> Enum.sum()
                |> Kernel./(m - 1)
          
          xi_std = :math.sqrt(
            Enum.map(xi_vals, fn x -> :math.pow(x - xi_mean, 2) end)
            |> Enum.sum()
            |> Kernel./(m - 1)
          )
          
          xj_std = :math.sqrt(
            Enum.map(xj_vals, fn x -> :math.pow(x - xj_mean, 2) end)
            |> Enum.sum()
            |> Kernel./(m - 1)
          )
          
          if xi_std * xj_std > 0 do
            cov / (xi_std * xj_std)
          else
            0.0
          end
        end
      end
    end
  end
  
  defp sample_from_copula(copula, param_keys, spec) do
    # Sample from multivariate normal with correlation
    n = copula.n
    
    # Generate independent standard normals
    z = List.duplicate(0, n) |> Enum.map(fn _ -> :rand.normal() end)
    
    # Apply correlation (simplified Cholesky)
    # For 2D case with correlation r: [z1, z2] -> [z1, r*z1 + sqrt(1-r^2)*z2]
    correlated = if n == 2 do
      r = copula.corr |> Enum.at(0) |> Enum.at(1)
      z1 = Enum.at(z, 0)
      z2 = Enum.at(z, 1)
      
      [z1, r * z1 + :math.sqrt(max(0, 1 - r*r)) * z2]
    else
      z  # For higher dimensions, use independent for simplicity
    end
    
    # Transform to uniform via normal CDF
    uniform = Enum.map(correlated, fn z_val ->
      # Approximate normal CDF
      0.5 * (1 + :math.erf(z_val / :math.sqrt(2)))
    end)
    
    # Transform back to parameter space
    Enum.zip(param_keys, uniform)
    |> Map.new(fn {k, u} ->
      {k, from_uniform(u, spec[k])}
    end)
  end
  
  defp select_best_ei(candidates, good_trials, bad_trials, param_keys, bandwidth) do
    scored = Enum.map(candidates, fn cand ->
      good_score = kde_likelihood(cand, good_trials, param_keys, bandwidth)
      bad_score = kde_likelihood(cand, bad_trials, param_keys, bandwidth)
      
      ei = if bad_score > 0 do
        good_score / bad_score
      else
        good_score
      end
      
      {cand, ei}
    end)
    
    {best, _} = Enum.max_by(scored, fn {_, score} -> score end)
    best
  end
  
  defp kde_likelihood(params, trials, param_keys, bandwidth) do
    if trials == [] do
      1.0e-10
    else
      scores = Enum.map(trials, fn trial ->
        # Compute distance in parameter space
        dist_sq = Enum.reduce(param_keys, 0.0, fn k, acc ->
          v1 = params[k] || 0.0
          v2 = Map.get(trial.params, k, 0.0) || 0.0
          
          # Normalize by range for fair comparison
          diff = abs(v1 - v2) / 10.0  # Assume range ~10 for simplicity
          acc + diff * diff
        end)
        
        # Gaussian kernel
        :math.exp(-dist_sq / (2 * bandwidth * bandwidth))
      end)
      
      Enum.sum(scores) / length(scores)
    end
  end
end