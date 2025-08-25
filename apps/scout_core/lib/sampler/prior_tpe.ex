defmodule Scout.Sampler.PriorTPE do
  @behaviour Scout.Sampler
  @moduledoc """
  TPE sampler with prior distribution support.
  
  This implementation allows incorporating domain knowledge through
  prior distributions, similar to Optuna's TPESampler(prior_weight) option.
  
  The prior acts as "virtual" observations that bias the optimization
  towards regions believed to be good based on domain expertise.
  """
  
  def init(opts) do
    base_state = Scout.Sampler.TPE.init(opts)
    
    Map.merge(base_state, %{
      # Weight for prior distribution (higher = stronger prior influence)
      prior_weight: Map.get(opts, :prior_weight, 1.0),
      # Prior distributions for each parameter
      priors: Map.get(opts, :priors, %{}),
      # Number of virtual observations from prior
      n_prior_samples: Map.get(opts, :n_prior_samples, 10)
    })
  end
  
  def next(space_fun, ix, history, state) do
    spec = space_fun.(ix)
    
    # Generate virtual observations from prior
    prior_observations = generate_prior_observations(
      spec,
      state.priors,
      state.prior_weight,
      state.n_prior_samples,
      state.goal
    )
    
    # Combine real history with prior observations
    augmented_history = prior_observations ++ history
    
    if length(history) < state.min_obs do
      # During startup, use more prior influence
      if length(prior_observations) > 0 do
        # Sample from prior-biased distribution
        sample_with_prior_bias(spec, state.priors, state.prior_weight)
      else
        # No prior, use random
        Scout.Sampler.RandomSearch.next(space_fun, ix, history, state)
      end
    else
      # Use TPE with augmented history
      tpe_state = Map.drop(state, [:prior_weight, :priors, :n_prior_samples])
      Scout.Sampler.TPE.next(space_fun, ix, augmented_history, tpe_state)
    end
  end
  
  # Generate virtual observations from prior distributions
  defp generate_prior_observations(spec, priors, weight, n_samples, goal) do
    if map_size(priors) == 0 do
      []
    else
      # Generate samples from prior
      prior_samples = for i <- 1..n_samples do
        params = sample_from_priors(spec, priors)
        
        # Assign synthetic score based on prior belief
        # Better scores for samples closer to prior means
        score = calculate_prior_score(params, priors, goal)
        
        %Scout.Trial{
          id: "prior-#{i}",
          study_id: "prior-study",
          params: params,
          score: score * weight,  # Weight the influence
          status: :completed,  # Purpose: use correct enum
          bracket: 0
        }
      end
      
      prior_samples
    end
  end
  
  # Sample parameters from prior distributions
  defp sample_from_priors(spec, priors) do
    Enum.reduce(spec, %{}, fn {key, param_spec}, acc ->
      prior = Map.get(priors, key)
      
      value = if prior do
        sample_from_prior(prior, param_spec)
      else
        # No prior for this parameter, sample uniformly
        sample_uniform(param_spec)
      end
      
      Map.put(acc, key, value)
    end)
  end
  
  # Sample from a specific prior distribution
  defp sample_from_prior(prior, param_spec) do
    case prior do
      {:normal, mean, std} ->
        value = mean + :rand.normal() * std
        constrain_to_spec(value, param_spec)
      
      {:beta, alpha, beta} ->
        # Beta distribution for [0, 1] range
        sample_beta(alpha, beta, param_spec)
      
      {:categorical, weights} ->
        # Weighted categorical distribution
        sample_categorical_weighted(weights, param_spec)
      
      {:truncated_normal, mean, std, min, max} ->
        # Truncated normal distribution
        sample_truncated_normal(mean, std, min, max, param_spec)
      
      {:log_normal, log_mean, log_std} ->
        # Log-normal distribution
        log_value = log_mean + :rand.normal() * log_std
        value = :math.exp(log_value)
        constrain_to_spec(value, param_spec)
      
      _ ->
        # Unknown prior type, fallback to uniform
        sample_uniform(param_spec)
    end
  end
  
  # Sample from beta distribution
  defp sample_beta(alpha, beta, param_spec) do
    # Simple beta sampling using ratio of gammas
    # For production, use a proper beta distribution library
    x = sample_gamma(alpha)
    y = sample_gamma(beta)
    beta_sample = x / (x + y)
    
    case param_spec do
      {:uniform, min, max} ->
        min + beta_sample * (max - min)
      _ ->
        beta_sample
    end
  end
  
  # Simple gamma sampling (for beta distribution)
  defp sample_gamma(shape) do
    # Simplified gamma sampling
    # For production, use proper gamma distribution
    Enum.reduce(1..round(shape), 0.0, fn _, acc ->
      acc - :math.log(:rand.uniform())
    end)
  end
  
  # Sample from weighted categorical distribution
  defp sample_categorical_weighted(weights, param_spec) do
    case param_spec do
      {:choice, choices} ->
        # Normalize weights to match choices
        normalized_weights = normalize_categorical_weights(weights, choices)
        weighted_random_choice(choices, normalized_weights)
      _ ->
        # Not a categorical parameter
        sample_uniform(param_spec)
    end
  end
  
  # Normalize categorical weights
  defp normalize_categorical_weights(weights, choices) do
    Enum.map(choices, fn choice ->
      Map.get(weights, choice, 1.0)
    end)
  end
  
  # Weighted random choice
  defp weighted_random_choice(choices, weights) do
    total = Enum.sum(weights)
    r = :rand.uniform() * total
    
    {selected, _} = Enum.zip(choices, weights)
                     |> Enum.reduce_while({nil, 0}, fn {choice, weight}, {_, cum} ->
                       new_cum = cum + weight
                       if new_cum >= r do
                         {:halt, {choice, new_cum}}
                       else
                         {:cont, {choice, new_cum}}
                       end
                     end)
    
    selected || List.first(choices)
  end
  
  # Sample from truncated normal
  defp sample_truncated_normal(mean, std, min, max, param_spec) do
    # Rejection sampling for truncated normal
    max_attempts = 100
    
    value = Enum.reduce_while(1..max_attempts, nil, fn _, _ ->
      sample = mean + :rand.normal() * std
      if sample >= min and sample <= max do
        {:halt, sample}
      else
        {:cont, nil}
      end
    end)
    
    value = value || mean  # Fallback to mean if rejection sampling fails
    constrain_to_spec(value, param_spec)
  end
  
  # Constrain value to parameter specification
  defp constrain_to_spec(value, param_spec) do
    case param_spec do
      {:uniform, min, max} ->
        max(min, min(max, value))
      
      {:log_uniform, min, max} when value > 0 ->
        max(min, min(max, value))
      
      {:int, min, max} ->
        round(max(min, min(max, value)))
      
      _ ->
        value
    end
  end
  
  # Sample uniformly from parameter specification
  defp sample_uniform(param_spec) do
    case param_spec do
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
      
      _ ->
        0.0
    end
  end
  
  # Calculate synthetic score for prior samples
  defp calculate_prior_score(params, priors, goal) do
    # Calculate likelihood under prior
    likelihood = Enum.reduce(params, 1.0, fn {key, value}, acc ->
      prior = Map.get(priors, key)
      
      if prior do
        acc * calculate_likelihood(value, prior)
      else
        acc
      end
    end)
    
    # Convert likelihood to score based on optimization goal
    case goal do
      :minimize -> -:math.log(likelihood + 1.0e-10)
      _ -> :math.log(likelihood + 1.0e-10)
    end
  end
  
  # Calculate likelihood of value under prior
  defp calculate_likelihood(value, prior) do
    case prior do
      {:normal, mean, std} ->
        # Normal distribution likelihood
        z = (value - mean) / std
        :math.exp(-0.5 * z * z) / (std * :math.sqrt(2 * :math.pi()))
      
      {:log_normal, log_mean, log_std} when value > 0 ->
        # Log-normal distribution likelihood
        log_value = :math.log(value)
        z = (log_value - log_mean) / log_std
        :math.exp(-0.5 * z * z) / (value * log_std * :math.sqrt(2 * :math.pi()))
      
      _ ->
        # Default likelihood
        1.0
    end
  end
  
  # Sample with prior bias during startup
  defp sample_with_prior_bias(spec, priors, weight) do
    params = if :rand.uniform() < weight / (weight + 1.0) do
      # Sample from prior
      sample_from_priors(spec, priors)
    else
      # Sample uniformly
      Enum.reduce(spec, %{}, fn {key, param_spec}, acc ->
        Map.put(acc, key, sample_uniform(param_spec))
      end)
    end
    
    {params, %{}}
  end
  
  @doc """
  Helper to create common prior distributions.
  """
  def normal_prior(mean, std), do: {:normal, mean, std}
  def beta_prior(alpha, beta), do: {:beta, alpha, beta}
  def categorical_prior(weights), do: {:categorical, weights}
  def truncated_normal_prior(mean, std, min, max), do: {:truncated_normal, mean, std, min, max}
  def log_normal_prior(log_mean, log_std), do: {:log_normal, log_mean, log_std}
end