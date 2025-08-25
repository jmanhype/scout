defmodule Scout.Sampler.TPEIntegrated do
  @behaviour Scout.Sampler
  @moduledoc """
  Integrated TPE that automatically selects univariate or multivariate
  based on the search space and configuration.
  
  This should replace the default TPE in production.
  """
  
  alias Scout.Sampler.RandomSearch
  
  def init(opts) do
    %{
      gamma: Map.get(opts, :gamma, 0.25),
      n_candidates: Map.get(opts, :n_candidates, 24),
      min_obs: Map.get(opts, :min_obs, 10),
      goal: Map.get(opts, :goal, :minimize),
      multivariate: Map.get(opts, :multivariate, :auto),  # auto, true, or false
      bandwidth_factor: Map.get(opts, :bandwidth_factor, 1.06)
    }
  end
  
  def next(space_fun, ix, history, state) do
    if length(history) < state.min_obs do
      RandomSearch.next(space_fun, ix, history, state)
    else
      spec = space_fun.(ix)
      param_keys = Map.keys(spec) |> Enum.sort()
      
      # Decide whether to use multivariate
      use_multivariate = case state.multivariate do
        :auto -> should_use_multivariate?(param_keys, spec)
        true -> true
        false -> false
      end
      
      if use_multivariate and length(param_keys) > 1 do
        # Use multivariate approach
        multivariate_sample(history, param_keys, spec, state)
      else
        # Use univariate approach
        univariate_sample(history, param_keys, spec, state)
      end
    end
  end
  
  defp should_use_multivariate?(param_keys, spec) do
    # Use multivariate if:
    # 1. Multiple numeric parameters exist
    # 2. Parameters are likely correlated (similar ranges)
    numeric_count = Enum.count(param_keys, fn k ->
      case spec[k] do
        {:uniform, _, _} -> true
        {:log_uniform, _, _} -> true
        {:int, _, _} -> true
        _ -> false
      end
    end)
    
    numeric_count > 1
  end
  
  defp multivariate_sample(history, param_keys, spec, state) do
    # Split history by performance
    {good_trials, bad_trials} = split_by_performance(history, state)
    
    # Build copula models
    good_copula = build_copula(good_trials, param_keys, spec)
    bad_copula = build_copula(bad_trials, param_keys, spec)
    
    # Generate candidates
    candidates = for i <- 1..state.n_candidates do
      cond do
        # 70% from good copula
        i <= round(state.n_candidates * 0.7) and good_copula != nil ->
          sample_from_copula(good_copula, param_keys, spec)
        # 20% from bad copula
        i <= round(state.n_candidates * 0.9) and bad_copula != nil ->
          sample_from_copula(bad_copula, param_keys, spec)
        # 10% random
        true ->
          Scout.SearchSpace.sample(spec)
      end
    end
    
    # Select best using EI
    best = select_best_ei(candidates, good_trials, bad_trials, param_keys, state)
    {best, state}
  end
  
  defp univariate_sample(history, param_keys, spec, state) do
    # Simple univariate sampling
    candidates = for _ <- 1..state.n_candidates do
      Scout.SearchSpace.sample(spec)
    end
    
    {good_trials, bad_trials} = split_by_performance(history, state)
    best = select_best_ei(candidates, good_trials, bad_trials, param_keys, state)
    {best, state}
  end
  
  defp split_by_performance(history, state) do
    sorted = case state.goal do
      :minimize -> Enum.sort_by(history, & &1.score)
      _ -> Enum.sort_by(history, & &1.score, :desc)
    end
    
    n_good = max(1, round(length(sorted) * state.gamma))
    Enum.split(sorted, n_good)
  end
  
  defp build_copula(trials, param_keys, spec) do
    if length(trials) < 2 do
      nil
    else
      uniform_data = Enum.map(trials, fn trial ->
        Enum.map(param_keys, fn k ->
          val = Map.get(trial.params, k, 0.0) || 0.0
          to_uniform(val, spec[k])
        end)
      end)
      
      corr = compute_correlation_matrix(uniform_data)
      
      %{
        data: uniform_data,
        corr: corr,
        n_params: length(param_keys)
      }
    end
  end
  
  defp to_uniform(val, spec_entry) do
    case spec_entry do
      {:uniform, min, max} ->
        (max(min, min(max, val)) - min) / (max - min + 1.0e-10)
      {:log_uniform, min, max} ->
        log_val = :math.log(max(min, min(max, val)))
        (:math.log(val) - :math.log(min)) / (:math.log(max) - :math.log(min) + 1.0e-10)
      {:int, min, max} ->
        (max(min, min(max, round(val))) - min) / (max - min + 1)
      _ -> 0.5
    end
  end
  
  defp from_uniform(u, spec_entry) do
    u = max(0.001, min(0.999, u))
    
    case spec_entry do
      {:uniform, min, max} ->
        min + u * (max - min)
      {:log_uniform, min, max} ->
        :math.exp(:math.log(min) + u * (:math.log(max) - :math.log(min)))
      {:int, min, max} ->
        round(min + u * (max - min))
      _ -> u
    end
  end
  
  defp compute_correlation_matrix(data) do
    n_dims = length(hd(data))
    n_samples = length(data)
    
    if n_samples < 3 do
      # Identity matrix
      for i <- 0..(n_dims-1), do: (for j <- 0..(n_dims-1), do: (if i == j, do: 1.0, else: 0.0))
    else
      means = for i <- 0..(n_dims-1) do
        col = Enum.map(data, fn row -> Enum.at(row, i) end)
        Enum.sum(col) / n_samples
      end
      
      for i <- 0..(n_dims-1) do
        for j <- 0..(n_dims-1) do
          if i == j do
            1.0
          else
            col_i = Enum.map(data, fn row -> Enum.at(row, i) end)
            col_j = Enum.map(data, fn row -> Enum.at(row, j) end)
            compute_correlation(col_i, col_j, Enum.at(means, i), Enum.at(means, j))
          end
        end
      end
    end
  end
  
  defp compute_correlation(col_i, col_j, mean_i, mean_j) do
    n = length(col_i)
    cov = Enum.zip(col_i, col_j)
          |> Enum.map(fn {xi, xj} -> (xi - mean_i) * (xj - mean_j) end)
          |> Enum.sum()
          |> Kernel./(n - 1)
    
    std_i = :math.sqrt(
      Enum.map(col_i, fn x -> :math.pow(x - mean_i, 2) end)
      |> Enum.sum()
      |> Kernel./(n - 1)
    )
    
    std_j = :math.sqrt(
      Enum.map(col_j, fn x -> :math.pow(x - mean_j, 2) end)
      |> Enum.sum()
      |> Kernel./(n - 1)
    )
    
    if std_i * std_j > 1.0e-10 do
      max(-1.0, min(1.0, cov / (std_i * std_j)))
    else
      0.0
    end
  end
  
  defp sample_from_copula(copula, param_keys, spec) do
    n = copula.n_params
    
    # Generate correlated samples
    z = for _ <- 1..n, do: :rand.normal()
    
    correlated = case n do
      2 ->
        # 2D case with exact correlation
        r = copula.corr |> Enum.at(0) |> Enum.at(1)
        [z1, z2] = z
        [z1, r * z1 + :math.sqrt(max(0, 1 - r*r)) * z2]
      _ ->
        # Higher dimensions
        z
    end
    
    # Transform to uniform
    uniform = Enum.map(correlated, fn z_val ->
      0.5 * (1 + :math.erf(z_val / :math.sqrt(2)))
    end)
    
    # Map to parameter space
    Enum.zip(param_keys, uniform)
    |> Map.new(fn {k, u} -> {k, from_uniform(u, spec[k])} end)
  end
  
  defp select_best_ei(candidates, good_trials, bad_trials, param_keys, state) do
    scored = Enum.map(candidates, fn cand ->
      good_score = kde_likelihood(cand, good_trials, param_keys, state.bandwidth_factor)
      bad_score = kde_likelihood(cand, bad_trials, param_keys, state.bandwidth_factor)
      
      ei = if bad_score > 1.0e-10 do
        good_score / bad_score
      else
        good_score * 1000
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
      n_dims = length(param_keys)
      h = bandwidth * :math.pow(length(trials), -1.0/(n_dims + 4))
      
      scores = Enum.map(trials, fn trial ->
        dist_sq = Enum.reduce(param_keys, 0.0, fn k, acc ->
          v1 = params[k] || 0.0
          v2 = Map.get(trial.params, k, 0.0) || 0.0
          
          scale = get_scale(k, trials)
          diff = if scale > 0, do: (v1 - v2) / scale, else: 0
          acc + diff * diff
        end)
        
        :math.exp(-dist_sq / (2 * h * h))
      end)
      
      max(1.0e-10, Enum.sum(scores) / length(scores))
    end
  end
  
  defp get_scale(param_key, trials) do
    values = Enum.map(trials, fn t -> 
      Map.get(t.params, param_key, 0.0) || 0.0
    end)
    
    if length(values) > 1 do
      range = Enum.max(values) - Enum.min(values)
      if range > 0, do: range, else: 1.0
    else
      1.0
    end
  end
end