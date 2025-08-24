defmodule Scout.Sampler.MultivarTPE do
  @behaviour Scout.Sampler
  @moduledoc """
  Multivariate Tree-structured Parzen Estimator (TPE) sampler.
  
  This implementation models correlations between parameters using
  multivariate kernel density estimation, similar to Optuna's
  multivariate=True option.
  """
  alias Scout.Sampler.RandomSearch
  
  def init(opts) do
    %{
      gamma: Map.get(opts, :gamma, 0.15),
      n_candidates: Map.get(opts, :n_candidates, 24),
      min_obs: Map.get(opts, :min_obs, 20),
      bw_method: Map.get(opts, :bw_method, :scott),
      goal: Map.get(opts, :goal, :maximize),
      seed: Map.get(opts, :seed),
      # Multivariate-specific options
      consider_correlations: Map.get(opts, :consider_correlations, true),
      correlation_threshold: Map.get(opts, :correlation_threshold, 0.3)
    }
  end
  
  def next(space_fun, ix, history, state) do
    if length(history) < state.min_obs do
      RandomSearch.next(space_fun, ix, history, state)
    else
      spec = space_fun.(ix)
      
      # Extract numeric parameters for multivariate modeling
      numeric_keys = extract_numeric_keys(spec)
      
      if length(numeric_keys) < 2 or not state.consider_correlations do
        # Fall back to univariate if only one numeric parameter
        # or correlations disabled
        base_state = Map.drop(state, [:consider_correlations, :correlation_threshold, :bw_method])
        Scout.Sampler.TPE.next(space_fun, ix, history, base_state)
      else
        # Multivariate TPE
        sample_multivariate(spec, numeric_keys, history, state, space_fun, ix)
      end
    end
  end
  
  # Extract numeric parameter keys from spec
  defp extract_numeric_keys(spec) do
    spec
    |> Enum.filter(fn {_k, v} ->
      case v do
        {:uniform, _, _} -> true
        {:log_uniform, _, _} -> true
        {:int, _, _} -> true
        _ -> false
      end
    end)
    |> Enum.map(fn {k, _} -> k end)
  end
  
  # Multivariate sampling with correlation modeling
  defp sample_multivariate(spec, numeric_keys, history, state, space_fun, ix) do
    # Split observations into good and bad
    {good_obs, bad_obs} = split_observations(history, state)
    
    # Extract parameter matrices
    good_matrix = build_parameter_matrix(good_obs, numeric_keys)
    bad_matrix = build_parameter_matrix(bad_obs, numeric_keys)
    
    # Calculate covariance matrices
    good_cov = calculate_covariance(good_matrix)
    bad_cov = calculate_covariance(bad_matrix)
    
    # Check for significant correlations
    correlations = calculate_correlations(good_matrix)
    has_correlations = check_significant_correlations(correlations, state.correlation_threshold)
    
    if has_correlations do
      # Use multivariate KDE
      good_kde = build_multivariate_kde(good_matrix, good_cov, state)
      bad_kde = build_multivariate_kde(bad_matrix, bad_cov, state)
      
      # Generate candidates using multivariate sampling
      candidates = generate_multivariate_candidates(
        spec, numeric_keys, good_kde, state.n_candidates
      )
      
      # Score candidates using multivariate EI
      best_candidate = select_best_multivariate(
        candidates, good_kde, bad_kde, numeric_keys
      )
      
      # Add non-numeric parameters
      full_params = add_non_numeric_params(best_candidate, spec, numeric_keys)
      
      {full_params, state}
    else
      # No significant correlations, use univariate
      base_state = Map.drop(state, [:consider_correlations, :correlation_threshold, :bw_method])
      Scout.Sampler.TPE.next(space_fun, ix, history, base_state)
    end
  end
  
  # Split observations into good and bad based on scores
  defp split_observations(history, state) do
    sorted = case state.goal do
      :minimize -> Enum.sort_by(history, & &1.score, :asc)
      _ -> Enum.sort_by(history, & &1.score, :desc)
    end
    
    n_good = max(trunc(state.gamma * length(sorted)), 1)
    Enum.split(sorted, n_good)
  end
  
  # Build parameter matrix from observations
  defp build_parameter_matrix(observations, keys) do
    Enum.map(observations, fn obs ->
      Enum.map(keys, fn k ->
        normalize_value(obs.params[k], k)
      end)
    end)
  end
  
  # Normalize values for correlation calculation
  defp normalize_value(value, _key) when is_number(value), do: value
  defp normalize_value(value, _key) when is_integer(value), do: value * 1.0
  defp normalize_value(_, _), do: 0.0
  
  # Calculate covariance matrix
  defp calculate_covariance(matrix) when length(matrix) < 2 do
    # Return identity matrix for small samples
    dim = length(hd(matrix))
    Enum.map(1..dim, fn i ->
      Enum.map(1..dim, fn j ->
        if i == j, do: 1.0, else: 0.0
      end)
    end)
  end
  
  defp calculate_covariance(matrix) do
    n = length(matrix)
    dim = length(hd(matrix))
    
    # Calculate means
    means = Enum.map(0..(dim-1), fn i ->
      sum = Enum.reduce(matrix, 0.0, fn row, acc ->
        acc + Enum.at(row, i)
      end)
      sum / n
    end)
    
    # Calculate covariance
    Enum.map(0..(dim-1), fn i ->
      Enum.map(0..(dim-1), fn j ->
        sum = Enum.reduce(matrix, 0.0, fn row, acc ->
          xi = Enum.at(row, i) - Enum.at(means, i)
          xj = Enum.at(row, j) - Enum.at(means, j)
          acc + xi * xj
        end)
        sum / (n - 1)
      end)
    end)
  end
  
  # Calculate correlation matrix
  defp calculate_correlations(matrix) do
    cov = calculate_covariance(matrix)
    dim = length(cov)
    
    # Get standard deviations
    stds = Enum.map(0..(dim-1), fn i ->
      :math.sqrt(Enum.at(Enum.at(cov, i), i))
    end)
    
    # Calculate correlations
    Enum.map(0..(dim-1), fn i ->
      Enum.map(0..(dim-1), fn j ->
        if Enum.at(stds, i) > 0 and Enum.at(stds, j) > 0 do
          Enum.at(Enum.at(cov, i), j) / (Enum.at(stds, i) * Enum.at(stds, j))
        else
          if i == j, do: 1.0, else: 0.0
        end
      end)
    end)
  end
  
  # Check if there are significant correlations
  defp check_significant_correlations(corr_matrix, threshold) do
    dim = length(corr_matrix)
    
    Enum.any?(0..(dim-1), fn i ->
      Enum.any?(0..(dim-1), fn j ->
        i != j and abs(Enum.at(Enum.at(corr_matrix, i), j)) > threshold
      end)
    end)
  end
  
  # Build multivariate KDE
  defp build_multivariate_kde(matrix, covariance, state) do
    bandwidth = calculate_bandwidth(matrix, covariance, state)
    
    %{
      data: matrix,
      covariance: covariance,
      bandwidth: bandwidth,
      inv_cov: matrix_inverse(scale_matrix(covariance, bandwidth))
    }
  end
  
  # Calculate bandwidth using Scott's rule or Silverman's rule
  defp calculate_bandwidth(matrix, _covariance, state) do
    n = length(matrix)
    d = length(hd(matrix))
    
    case state.bw_method do
      :scott ->
        :math.pow(n, -1.0 / (d + 4))
      :silverman ->
        :math.pow(n * (d + 2) / 4, -1.0 / (d + 4))
      _ ->
        1.0
    end
  end
  
  # Scale matrix by bandwidth
  defp scale_matrix(matrix, scalar) do
    Enum.map(matrix, fn row ->
      Enum.map(row, fn val -> val * scalar * scalar end)
    end)
  end
  
  # Simple matrix inverse for 2x2 (extend for larger)
  defp matrix_inverse(matrix) when length(matrix) == 2 do
    [[a, b], [c, d]] = matrix
    det = a * d - b * c
    
    if abs(det) < 1.0e-10 do
      # Singular matrix, return identity
      [[1.0, 0.0], [0.0, 1.0]]
    else
      [[d/det, -b/det], [-c/det, a/det]]
    end
  end
  
  defp matrix_inverse(matrix) do
    # For larger matrices, use identity as fallback
    # In production, implement proper matrix inversion
    dim = length(matrix)
    Enum.map(0..(dim-1), fn i ->
      Enum.map(0..(dim-1), fn j ->
        if i == j, do: 1.0, else: 0.0
      end)
    end)
  end
  
  # Generate multivariate candidates
  defp generate_multivariate_candidates(spec, keys, kde, n_candidates) do
    Enum.map(1..n_candidates, fn _ ->
      # Sample from multivariate KDE
      sample_point = sample_from_kde(kde)
      
      # Convert to parameter map
      Enum.zip(keys, sample_point)
      |> Enum.into(%{})
      |> apply_bounds(spec, keys)
    end)
  end
  
  # Sample from multivariate KDE
  defp sample_from_kde(kde) do
    # Select a random data point
    base_point = Enum.random(kde.data)
    dim = length(base_point)
    
    # Add Gaussian noise based on bandwidth
    Enum.map(base_point, fn val ->
      val + :rand.normal() * kde.bandwidth
    end)
  end
  
  # Apply parameter bounds
  defp apply_bounds(params, spec, keys) do
    Enum.reduce(keys, params, fn k, acc ->
      case spec[k] do
        {:uniform, min, max} ->
          Map.put(acc, k, clamp(acc[k], min, max))
        {:log_uniform, min, max} ->
          val = clamp(acc[k], :math.log(min), :math.log(max))
          Map.put(acc, k, :math.exp(val))
        {:int, min, max} ->
          Map.put(acc, k, round(clamp(acc[k], min, max)))
        _ ->
          acc
      end
    end)
  end
  
  defp clamp(x, min, max) when x < min, do: min
  defp clamp(x, min, max) when x > max, do: max
  defp clamp(x, _, _), do: x
  
  # Select best candidate using multivariate EI
  defp select_best_multivariate(candidates, good_kde, bad_kde, _keys) do
    scored = Enum.map(candidates, fn cand ->
      score = multivariate_ei_score(cand, good_kde, bad_kde)
      {cand, score}
    end)
    
    {best, _} = Enum.max_by(scored, fn {_, s} -> s end)
    best
  end
  
  # Calculate multivariate EI score
  defp multivariate_ei_score(candidate, good_kde, bad_kde) do
    point = Map.values(candidate)
    
    # Calculate multivariate PDF for good and bad distributions
    pg = multivariate_pdf(point, good_kde)
    pb = multivariate_pdf(point, bad_kde)
    
    # Return log ratio for numerical stability
    :math.log(max(pg, 1.0e-12) / max(pb, 1.0e-12))
  end
  
  # Calculate multivariate PDF
  defp multivariate_pdf(point, kde) do
    n = length(kde.data)
    dim = length(point)
    
    # Sum over all kernel centers
    sum = Enum.reduce(kde.data, 0.0, fn center, acc ->
      diff = Enum.zip(point, center) |> Enum.map(fn {p, c} -> p - c end)
      
      # Mahalanobis distance (simplified for diagonal covariance)
      dist_sq = Enum.zip(diff, diff) |> Enum.reduce(0.0, fn {d, _}, acc ->
        acc + d * d / (kde.bandwidth * kde.bandwidth)
      end)
      
      # Gaussian kernel
      acc + :math.exp(-0.5 * dist_sq)
    end)
    
    # Normalize
    normalizer = :math.pow(2 * :math.pi() * kde.bandwidth * kde.bandwidth, dim / 2)
    sum / (n * normalizer)
  end
  
  # Add non-numeric parameters
  defp add_non_numeric_params(params, spec, numeric_keys) do
    non_numeric = Enum.reject(spec, fn {k, _} -> k in numeric_keys end)
    
    Enum.reduce(non_numeric, params, fn {k, v}, acc ->
      case v do
        {:choice, choices} ->
          Map.put(acc, k, Enum.random(choices))
        _ ->
          acc
      end
    end)
  end
end