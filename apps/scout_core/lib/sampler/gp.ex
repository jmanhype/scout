defmodule Scout.Sampler.GP do
  @moduledoc """
  Gaussian Process (GP) based Bayesian Optimization sampler.
  
  Uses a Gaussian Process surrogate model to predict the objective function
  and acquisition functions (EI, UCB, PI) to guide the search.
  
  Equivalent to Optuna's GPSampler and similar to Scikit-Optimize.
  """
  
  @behaviour Scout.Sampler
  
  @default_n_startup_trials 10
  @default_acquisition_func :ei  # Expected Improvement
  @default_kernel :matern52
  @default_alpha 1.0e-6  # Noise level
  @default_normalize_y true
  @default_xi 0.01  # Exploration parameter for EI
  @default_kappa 1.96  # Exploration parameter for UCB
  
  def init(opts \\ %{}) do
    %{
      n_startup_trials: Map.get(opts, :n_startup_trials, @default_n_startup_trials),
      acquisition_func: Map.get(opts, :acquisition_func, @default_acquisition_func),
      kernel: Map.get(opts, :kernel, @default_kernel),
      alpha: Map.get(opts, :alpha, @default_alpha),
      normalize_y: Map.get(opts, :normalize_y, @default_normalize_y),
      xi: Map.get(opts, :xi, @default_xi),
      kappa: Map.get(opts, :kappa, @default_kappa),
      length_scales: Map.get(opts, :length_scales, %{}),
      gp_model: nil,
      seed: Map.get(opts, :seed)
    }
  end
  
  def next(space_fun, ix, history, state) do
    # Set random seed if provided
    if state.seed do
      :rand.seed(:exsplus, {state.seed, ix, 0})
    end
    
    # Get search space
    spec = space_fun.(ix)
    
    # Use random sampling for startup trials
    if length(history) < state.n_startup_trials do
      params = random_sample(spec)
      {params, state}
    else
      # Build or update GP model
      state = update_gp_model(state, history, spec)
      
      # Optimize acquisition function to get next point
      params = optimize_acquisition(state, spec)
      
      {params, state}
    end
  end
  
  defp random_sample(spec) do
    for {param_name, param_spec} <- spec, into: %{} do
      value = case param_spec do
        {:uniform, min, max} ->
          min + :rand.uniform() * (max - min)
        {:log_uniform, min, max} ->
          log_min = :math.log(min)
          log_max = :math.log(max)
          :math.exp(log_min + :rand.uniform() * (log_max - log_min))
        {:int, min, max} ->
          min + :rand.uniform(max - min + 1) - 1
        {:choice, choices} ->
          Enum.random(choices)
      end
      
      {param_name, value}
    end
  end
  
  defp update_gp_model(state, history, spec) do
    # Extract X (parameters) and y (objectives) from history
    {x_train, y_train} = prepare_training_data(history, spec)
    
    # Normalize y values if requested
    {y_normalized, y_mean, y_std} = if state.normalize_y do
      normalize_values(y_train)
    else
      {y_train, 0.0, 1.0}
    end
    
    # Build kernel
    kernel = build_kernel(state.kernel, spec, state.length_scales)
    
    # Fit GP model
    gp_model = fit_gp(x_train, y_normalized, kernel, state.alpha)
    
    %{state | 
      gp_model: Map.merge(gp_model, %{
        y_mean: y_mean,
        y_std: y_std,
        x_train: x_train,
        y_train: y_train
      })
    }
  end
  
  defp prepare_training_data(history, spec) do
    # Convert history to feature matrix and target vector
    valid_trials = history
    |> Enum.filter(&(&1.score != nil))
    |> Enum.take(-100)  # Limit to recent trials for efficiency
    
    x_train = valid_trials
    |> Enum.map(fn trial ->
      encode_parameters(trial.params, spec)
    end)
    
    y_train = valid_trials
    |> Enum.map(&(&1.score))
    
    {x_train, y_train}
  end
  
  defp encode_parameters(params, spec) do
    # Convert parameters to numerical vector
    spec
    |> Enum.map(fn {param_name, param_spec} ->
      value = Map.get(params, param_name)
      
      case param_spec do
        {:uniform, min, max} ->
          # Scale to [0, 1]
          (value - min) / (max - min)
        {:log_uniform, min, max} ->
          # Log scale to [0, 1]
          log_min = :math.log(min)
          log_max = :math.log(max)
          (:math.log(value) - log_min) / (log_max - log_min)
        {:int, min, max} ->
          # Scale to [0, 1]
          (value - min) / (max - min)
        {:choice, choices} ->
          # One-hot encoding
          Enum.find_index(choices, &(&1 == value)) / max(1, length(choices) - 1)
      end
    end)
  end
  
  defp decode_parameters(encoded_values, spec) do
    # Convert numerical vector back to parameters
    spec
    |> Enum.zip(encoded_values)
    |> Enum.map(fn {{param_name, param_spec}, encoded_value} ->
      value = case param_spec do
        {:uniform, min, max} ->
          min + encoded_value * (max - min)
        {:log_uniform, min, max} ->
          log_min = :math.log(min)
          log_max = :math.log(max)
          :math.exp(log_min + encoded_value * (log_max - log_min))
        {:int, min, max} ->
          round(min + encoded_value * (max - min))
        {:choice, choices} ->
          idx = round(encoded_value * (length(choices) - 1))
          Enum.at(choices, idx)
      end
      
      {param_name, value}
    end)
    |> Enum.into(%{})
  end
  
  defp normalize_values(values) do
    mean = Enum.sum(values) / length(values)
    variance = values
    |> Enum.map(fn v -> :math.pow(v - mean, 2) end)
    |> Enum.sum()
    |> Kernel./(length(values))
    
    std = :math.sqrt(max(variance, 1.0e-10))
    
    normalized = Enum.map(values, fn v -> (v - mean) / std end)
    
    {normalized, mean, std}
  end
  
  defp build_kernel(:rbf, spec, length_scales) do
    # Radial Basis Function (Gaussian) kernel
    _dim = map_size(spec)
    ls = get_length_scales(length_scales, spec, 1.0)
    
    fn x1, x2 ->
      dist_sq = x1
      |> Enum.zip(x2)
      |> Enum.zip(ls)
      |> Enum.map(fn {{v1, v2}, l} ->
        :math.pow((v1 - v2) / l, 2)
      end)
      |> Enum.sum()
      
      :math.exp(-0.5 * dist_sq)
    end
  end
  
  defp build_kernel(:matern52, spec, length_scales) do
    # Matérn 5/2 kernel - good default for optimization
    _dim = map_size(spec)
    ls = get_length_scales(length_scales, spec, 1.0)
    
    fn x1, x2 ->
      r = x1
      |> Enum.zip(x2)
      |> Enum.zip(ls)
      |> Enum.map(fn {{v1, v2}, l} ->
        abs(v1 - v2) / l
      end)
      |> Enum.sum()
      |> Kernel.*(:math.sqrt(5))
      
      (1 + r + r * r / 3) * :math.exp(-r)
    end
  end
  
  defp build_kernel(:matern32, spec, length_scales) do
    # Matérn 3/2 kernel
    _dim = map_size(spec)
    ls = get_length_scales(length_scales, spec, 1.0)
    
    fn x1, x2 ->
      r = x1
      |> Enum.zip(x2)
      |> Enum.zip(ls)
      |> Enum.map(fn {{v1, v2}, l} ->
        abs(v1 - v2) / l
      end)
      |> Enum.sum()
      |> Kernel.*(:math.sqrt(3))
      
      (1 + r) * :math.exp(-r)
    end
  end
  
  defp get_length_scales(length_scales, spec, default) do
    spec
    |> Enum.map(fn {param_name, _} ->
      Map.get(length_scales, param_name, default)
    end)
  end
  
  defp fit_gp(x_train, y_train, kernel, alpha) do
    # Compute kernel matrix
    n = length(x_train)
    k_matrix = for i <- 0..(n-1), j <- 0..(n-1) do
      x_i = Enum.at(x_train, i)
      x_j = Enum.at(x_train, j)
      
      k_val = kernel.(x_i, x_j)
      
      # Add noise to diagonal
      if i == j do
        k_val + alpha
      else
        k_val
      end
    end
    |> Enum.chunk_every(n)
    
    # Compute Cholesky decomposition for efficient solving
    l_matrix = cholesky(k_matrix)
    
    # Solve L * alpha = y_train
    alpha_coeffs = solve_triangular(l_matrix, y_train, :lower)
    
    %{
      kernel: kernel,
      l_matrix: l_matrix,
      alpha_coeffs: alpha_coeffs,
      x_train: x_train,
      y_train: y_train
    }
  end
  
  defp predict_gp(gp_model, x_test) do
    # Compute kernel vector between test point and training points
    k_star = gp_model.x_train
    |> Enum.map(fn x_train ->
      gp_model.kernel.(x_test, x_train)
    end)
    
    # Mean prediction
    mean = k_star
    |> Enum.zip(gp_model.alpha_coeffs)
    |> Enum.map(fn {k, a} -> k * a end)
    |> Enum.sum()
    
    # Variance prediction
    v = solve_triangular(gp_model.l_matrix, k_star, :lower)
    var = 1.0 - (v |> Enum.map(&(&1 * &1)) |> Enum.sum())
    std = :math.sqrt(max(var, 1.0e-10))
    
    # Denormalize if needed
    mean_denorm = mean * gp_model.y_std + gp_model.y_mean
    std_denorm = std * gp_model.y_std
    
    {mean_denorm, std_denorm}
  end
  
  defp optimize_acquisition(state, spec) do
    # Multi-start optimization of acquisition function
    n_restarts = 10
    
    candidates = for _ <- 1..n_restarts do
      # Random starting point
      x0 = for _ <- 1..map_size(spec), do: :rand.uniform()
      
      # L-BFGS-B optimization (simplified with gradient descent)
      optimize_from_point(x0, state, spec)
    end
    
    # Select best candidate
    best = candidates
    |> Enum.max_by(fn x ->
      acquisition_value(x, state)
    end)
    
    decode_parameters(best, spec)
  end
  
  defp optimize_from_point(x0, state, _spec) do
    # Simplified gradient-based optimization
    learning_rate = 0.1
    n_iters = 50
    
    Enum.reduce(1..n_iters, x0, fn _, x ->
      # Compute gradient numerically
      grad = numerical_gradient(x, state)
      
      # Update with gradient ascent (maximizing acquisition)
      x_new = x
      |> Enum.zip(grad)
      |> Enum.map(fn {xi, gi} ->
        # Clip to [0, 1]
        max(0, min(1, xi + learning_rate * gi))
      end)
      
      x_new
    end)
  end
  
  defp numerical_gradient(x, state) do
    eps = 1.0e-6
    
    x
    |> Enum.with_index()
    |> Enum.map(fn {_, i} ->
      # Forward difference
      x_plus = List.update_at(x, i, &(&1 + eps))
      x_minus = List.update_at(x, i, &(&1 - eps))
      
      f_plus = acquisition_value(x_plus, state)
      f_minus = acquisition_value(x_minus, state)
      
      (f_plus - f_minus) / (2 * eps)
    end)
  end
  
  defp acquisition_value(x, state) do
    {mean, std} = predict_gp(state.gp_model, x)
    
    case state.acquisition_func do
      :ei -> expected_improvement(mean, std, state)
      :ucb -> upper_confidence_bound(mean, std, state)
      :pi -> probability_improvement(mean, std, state)
      :lcb -> -upper_confidence_bound(-mean, std, state)  # For maximization
    end
  end
  
  defp expected_improvement(mean, std, state) do
    # Current best value (assuming minimization)
    f_best = Enum.min(state.gp_model.y_train)
    
    if std < 1.0e-10 do
      0.0
    else
      z = (f_best - mean - state.xi) / std
      ei = std * (z * normal_cdf(z) + normal_pdf(z))
      ei
    end
  end
  
  defp upper_confidence_bound(mean, std, state) do
    # UCB = mean - kappa * std (for minimization)
    -mean + state.kappa * std
  end
  
  defp probability_improvement(mean, std, state) do
    f_best = Enum.min(state.gp_model.y_train)
    
    if std < 1.0e-10 do
      if mean < f_best, do: 1.0, else: 0.0
    else
      z = (f_best - mean - state.xi) / std
      normal_cdf(z)
    end
  end
  
  # Matrix operations (simplified implementations)
  
  defp cholesky(matrix) do
    n = length(matrix)
    l = List.duplicate(List.duplicate(0.0, n), n)
    
    Enum.reduce(0..(n-1), l, fn i, l_acc ->
      Enum.reduce(0..i, l_acc, fn j, l_acc2 ->
        if i == j do
          # Diagonal element
          sum_sq = if j > 0 do
            0..(j-1)
            |> Enum.map(fn k ->
              elem_at(l_acc2, j, k) * elem_at(l_acc2, j, k)
            end)
            |> Enum.sum()
          else
            0.0
          end
          
          val = :math.sqrt(elem_at(matrix, j, j) - sum_sq)
          set_elem(l_acc2, j, j, val)
        else
          # Off-diagonal element
          sum_prod = if j > 0 do
            0..(j-1)
            |> Enum.map(fn k ->
              elem_at(l_acc2, i, k) * elem_at(l_acc2, j, k)
            end)
            |> Enum.sum()
          else
            0.0
          end
          
          val = (elem_at(matrix, i, j) - sum_prod) / elem_at(l_acc2, j, j)
          set_elem(l_acc2, i, j, val)
        end
      end)
    end)
  end
  
  defp solve_triangular(l_matrix, b, :lower) do
    n = length(b)
    x = List.duplicate(0.0, n)
    
    Enum.reduce(0..(n-1), x, fn i, x_acc ->
      sum = if i > 0 do
        0..(i-1)
        |> Enum.map(fn j ->
          elem_at(l_matrix, i, j) * Enum.at(x_acc, j)
        end)
        |> Enum.sum()
      else
        0.0
      end
      
      val = (Enum.at(b, i) - sum) / elem_at(l_matrix, i, i)
      List.replace_at(x_acc, i, val)
    end)
  end
  
  defp elem_at(matrix, i, j) do
    matrix |> Enum.at(i) |> Enum.at(j)
  end
  
  defp set_elem(matrix, i, j, value) do
    row = Enum.at(matrix, i)
    new_row = List.replace_at(row, j, value)
    List.replace_at(matrix, i, new_row)
  end
  
  defp normal_cdf(z) do
    0.5 * (1 + erf(z / :math.sqrt(2)))
  end
  
  defp normal_pdf(z) do
    :math.exp(-0.5 * z * z) / :math.sqrt(2 * :math.pi())
  end
  
  defp erf(x) do
    # Approximation of error function
    a1 =  0.254829592
    a2 = -0.284496736
    a3 =  1.421413741
    a4 = -1.453152027
    a5 =  1.061405429
    p  =  0.3275911
    
    sign = if x < 0, do: -1, else: 1
    x = abs(x)
    
    t = 1.0 / (1.0 + p * x)
    y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * :math.exp(-x * x)
    
    sign * y
  end
end