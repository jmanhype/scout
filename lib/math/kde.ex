defmodule Scout.Math.KDE do
  @moduledoc """
  Numerically stable Kernel Density Estimation for TPE sampler.
  
  CRITICAL MATHEMATICAL FIXES:
  - Silverman's rule of thumb for bandwidth selection
  - Numerical stability via log-sum-exp trick
  - Epsilon floor to prevent zero probabilities
  - Handles edge cases: empty data, single point, identical points
  - No division by zero or NaN/Inf propagation
  """

  require Logger

  # Numerical stability constants
  @eps 1.0e-12
  @log_eps :math.log(@eps)
  @sqrt_2pi :math.sqrt(2.0 * :math.pi())

  @typedoc "A KDE function that returns log-probability for any input"
  @type kde_fn :: (number() -> float())

  @doc """
  Build Gaussian KDE from sample points.
  
  Uses Silverman's rule of thumb: h = 1.06 * σ * n^(-1/5)
  Returns function that computes log-density for numerical stability.
  
  Edge cases:
  - Empty list: returns uniform distribution (constant log-prob)
  - Single point: returns delta function (high prob at point, low elsewhere)  
  - Identical points: returns delta function
  - Normal case: returns proper KDE
  """
  @spec gaussian_kde([number()]) :: kde_fn()
  def gaussian_kde([]), do: fn _x -> @log_eps end
  
  def gaussian_kde([x]) do
    # Delta function: high probability near the point, low elsewhere
    fn query ->
      distance = abs(query - x)
      if distance < 1.0e-6, do: 0.0, else: @log_eps  # log(1.0) = 0, log(eps) for far points
    end
  end
  
  def gaussian_kde(points) when length(points) >= 2 do
    n = length(points)
    
    # Compute sample statistics
    mean = Enum.sum(points) / n
    variance = compute_variance(points, mean, n)
    
    # Handle degenerate case: all points identical
    if variance < @eps do
      # All points are essentially the same - use delta function
      gaussian_kde([hd(points)])
    else
      # Silverman's rule of thumb for bandwidth
      std_dev = :math.sqrt(variance)
      bandwidth = 1.06 * std_dev * :math.pow(n, -0.2)  # n^(-1/5)
      bandwidth = max(bandwidth, @eps)  # Ensure minimum bandwidth
      
      build_kde_function(points, bandwidth, n)
    end
  end

  @doc """
  Compute KDE with custom bandwidth.
  Useful for testing or when you have domain knowledge about optimal bandwidth.
  """
  @spec gaussian_kde_with_bandwidth([number()], float()) :: kde_fn()
  def gaussian_kde_with_bandwidth(points, bandwidth) when bandwidth > 0 do
    case points do
      [] -> fn _x -> @log_eps end
      [x] -> fn query -> if abs(query - x) < bandwidth/10, do: 0.0, else: @log_eps end
      _ -> build_kde_function(points, bandwidth, length(points))
    end
  end

  # Private helpers

  @spec compute_variance([number()], float(), pos_integer()) :: float()
  defp compute_variance(points, mean, n) do
    sum_sq_dev = Enum.reduce(points, 0.0, fn x, acc ->
      dev = x - mean
      acc + dev * dev
    end)
    
    # Use n-1 for sample variance (Bessel's correction)
    denominator = max(n - 1, 1)
    sum_sq_dev / denominator
  end

  @spec build_kde_function([number()], float(), pos_integer()) :: kde_fn()
  defp build_kde_function(points, bandwidth, n) do
    log_norm_const = :math.log(n * bandwidth * @sqrt_2pi)
    inv_2h2 = -0.5 / (bandwidth * bandwidth)
    
    fn query ->
      # Compute log-probabilities for numerical stability
      log_terms = for xi <- points do
        diff = query - xi
        inv_2h2 * diff * diff  # log of gaussian kernel (without normalization)
      end
      
      # Log-sum-exp trick for numerical stability
      case log_terms do
        [] -> @log_eps
        [single] -> single - log_norm_const
        _ ->
          max_log = Enum.max(log_terms)
          if max_log == :neg_infinity do
            @log_eps
          else
            # log(sum(exp(log_terms))) = max_log + log(sum(exp(log_terms - max_log)))
            sum_exp = Enum.reduce(log_terms, 0.0, fn log_term, acc ->
              acc + :math.exp(log_term - max_log)
            end)
            
            result = max_log + :math.log(sum_exp) - log_norm_const
            max(result, @log_eps)  # Floor at epsilon
          end
      end
    end
  end

  @doc """
  Convert log-density to regular density.
  Safe against underflow - returns epsilon for very small values.
  """
  @spec exp_density(float()) :: float()
  def exp_density(log_density) when log_density <= @log_eps, do: @eps
  def exp_density(log_density), do: :math.exp(log_density)

  @doc """
  Evaluate KDE at multiple points efficiently.
  Returns list of log-densities.
  """
  @spec evaluate_multiple(kde_fn(), [number()]) :: [float()]
  def evaluate_multiple(kde_fn, points) do
    for x <- points, do: kde_fn.(x)
  end

  @doc """
  Compute optimal bandwidth using Silverman's rule.
  Exposed for testing and analysis.
  """
  @spec silverman_bandwidth([number()]) :: float()
  def silverman_bandwidth([]), do: @eps
  def silverman_bandwidth([_]), do: @eps
  def silverman_bandwidth(points) do
    n = length(points)
    mean = Enum.sum(points) / n
    variance = compute_variance(points, mean, n)
    std_dev = :math.sqrt(max(variance, @eps))
    
    bandwidth = 1.06 * std_dev * :math.pow(n, -0.2)
    max(bandwidth, @eps)
  end

  @doc """
  Validate KDE properties for testing.
  
  Checks:
  - KDE never returns NaN or Infinity
  - KDE returns values >= epsilon (non-zero probability)
  - Bandwidth computation is sane
  """
  @spec validate_kde(kde_fn(), [number()]) :: :ok | {:error, term()}
  def validate_kde(kde_fn, test_points) when length(test_points) > 0 do
    try do
      for x <- test_points do
        density = kde_fn.(x)
        
        cond do
          not is_float(density) -> throw({:invalid_type, density})
          not is_finite(density) -> throw({:not_finite, density})
          density < @log_eps -> throw({:below_epsilon, density})
          true -> :ok
        end
      end
      
      :ok
    catch
      {:invalid_type, val} -> {:error, {:invalid_return_type, val}}
      {:not_finite, val} -> {:error, {:infinite_or_nan, val}}
      {:below_epsilon, val} -> {:error, {:below_minimum_density, val}}
    end
  end

  defp is_finite(x) when is_float(x) do
    x == x and x != :pos_infinity and x != :neg_infinity
  end
  defp is_finite(_), do: false
end