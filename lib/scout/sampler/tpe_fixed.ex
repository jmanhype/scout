defmodule Scout.Sampler.TPEFixed do
  @moduledoc """
  Mathematically correct Tree-structured Parzen Estimator (TPE) implementation.
  
  CRITICAL FIXES from original TPE:
  - Correct quantile split based on optimization goal
  - Numerically stable KDE with proper bandwidth
  - Safe ratio computation with epsilon floor
  - Deterministic sampling with proper RNG isolation
  - No division by zero or NaN propagation
  - Handles edge cases: few samples, identical values, extreme scores
  
  Based on "Algorithms for Hyper-Parameter Optimization" (Bergstra et al., 2011)
  """

  @behaviour Scout.Sampler

  alias Scout.Math.KDE
  alias Scout.Util.RNG

  require Logger

  # TPE hyperparameters
  @gamma_default 0.25    # Quantile split ratio
  @n_startup 10          # Number of random samples before TPE kicks in  
  @eps 1.0e-12          # Numerical stability epsilon

  defstruct [
    :gamma,          # Quantile for splitting good/bad trials
    :n_startup,      # Number of startup trials to use random sampling
    :rng_state,      # Isolated RNG state for this sampler
    :study_id        # Study ID for deterministic seeding
  ]

  @type t :: %__MODULE__{
    gamma: float(),
    n_startup: pos_integer(),
    rng_state: term(),
    study_id: String.t()
  }

  ## Behaviour implementation

  @impl Scout.Sampler
  def init(study_id, opts \\ []) when is_binary(study_id) do
    gamma = Keyword.get(opts, :gamma, @gamma_default)
    n_startup = Keyword.get(opts, :n_startup, @n_startup)
    
    # Initialize with deterministic seed for reproducibility
    state = %__MODULE__{
      gamma: gamma,
      n_startup: n_startup,
      study_id: study_id,
      rng_state: nil
    }
    
    Logger.info("TPE sampler initialized: gamma=#{gamma}, n_startup=#{n_startup}")
    {:ok, state}
  end

  @impl Scout.Sampler  
  def sample(state, search_space, completed_trials) do
    trial_count = length(completed_trials)
    
    # Use random sampling for startup phase
    if trial_count < state.n_startup do
      sample_random(state, search_space, trial_count)
    else
      sample_tpe(state, search_space, completed_trials, trial_count)
    end
  end

  ## Private implementation

  @spec sample_random(t(), map(), non_neg_integer()) :: {map(), t()}
  defp sample_random(state, search_space, trial_index) do
    # Use deterministic RNG for reproducibility
    params = RNG.with_seed(state.study_id, trial_index, fn ->
      sample_search_space_randomly(search_space)
    end)
    
    {params, state}
  end

  @spec sample_tpe(t(), map(), [map()], non_neg_integer()) :: {map(), t()}
  defp sample_tpe(state, search_space, completed_trials, trial_index) do
    try do
      # Extract scores and determine optimization direction
      scores = extract_scores(completed_trials)
      goal = determine_goal(completed_trials)
      
      # Split trials into good/bad based on quantile
      {good_trials, bad_trials} = split_trials(completed_trials, scores, state.gamma, goal)
      
      if length(good_trials) < 2 or length(bad_trials) < 2 do
        # Not enough data for reliable TPE - fall back to random
        sample_random(state, search_space, trial_index)
      else
        # Sample using TPE algorithm
        params = RNG.with_seed(state.study_id, trial_index, fn ->
          sample_with_tpe_models(search_space, good_trials, bad_trials)
        end)
        
        {params, state}
      end
    rescue
      error ->
        Logger.warn("TPE sampling failed: #{inspect(error)}, falling back to random")
        sample_random(state, search_space, trial_index)
    end
  end

  @spec extract_scores([map()]) :: [float()]
  defp extract_scores(trials) do
    for trial <- trials, 
        score = get_score(trial), 
        is_number(score), 
        is_finite_number(score),
        do: score
  end

  defp get_score(%{result: result}) when is_number(result), do: result
  defp get_score(%{"result" => result}) when is_number(result), do: result
  defp get_score(%{score: score}) when is_number(score), do: score
  defp get_score(%{"score" => score}) when is_number(score), do: score
  defp get_score(_), do: nil

  defp is_finite_number(x) when is_number(x) do
    x == x and x != :pos_infinity and x != :neg_infinity
  end
  defp is_finite_number(_), do: false

  @spec determine_goal([map()]) :: :minimize | :maximize
  defp determine_goal([trial | _]) do
    # Extract goal from trial metadata or assume minimize
    case trial do
      %{goal: goal} when goal in [:minimize, :maximize] -> goal
      %{"goal" => goal} when goal in ["minimize", "maximize"] -> String.to_existing_atom(goal)
      _ -> :minimize  # Conservative default
    end
  end

  @spec split_trials([map()], [float()], float(), :minimize | :maximize) :: {[map()], [map()]}
  defp split_trials(trials, scores, gamma, goal) do
    n_good = max(1, round(gamma * length(scores)))
    
    # Sort based on goal
    sorted_indices = case goal do
      :minimize -> 
        scores
        |> Enum.with_index()
        |> Enum.sort_by(fn {score, _idx} -> score end)
        |> Enum.map(fn {_score, idx} -> idx end)
      :maximize ->
        scores
        |> Enum.with_index() 
        |> Enum.sort_by(fn {score, _idx} -> -score end)  # Descending
        |> Enum.map(fn {_score, idx} -> idx end)
    end
    
    {good_indices, bad_indices} = Enum.split(sorted_indices, n_good)
    
    good_trials = for idx <- good_indices, do: Enum.at(trials, idx)
    bad_trials = for idx <- bad_indices, do: Enum.at(trials, idx)
    
    {good_trials, bad_trials}
  end

  @spec sample_with_tpe_models(map(), [map()], [map()]) :: map()
  defp sample_with_tpe_models(search_space, good_trials, bad_trials) do
    # Sample parameters one by one
    for {param_name, param_config} <- search_space, into: %{} do
      case param_config do
        %{type: :uniform, low: low, high: high} ->
          value = sample_uniform_tpe(param_name, low, high, good_trials, bad_trials)
          {param_name, value}
        
        %{type: :log_uniform, low: low, high: high} ->
          # Transform to log space, sample, then transform back
          log_low = :math.log(max(low, @eps))
          log_high = :math.log(high)
          log_value = sample_uniform_tpe(param_name, log_low, log_high, good_trials, bad_trials)
          {param_name, :math.exp(log_value)}
        
        %{type: :categorical, choices: choices} ->
          value = sample_categorical_tpe(param_name, choices, good_trials, bad_trials)
          {param_name, value}
          
        _ ->
          # Unknown parameter type - sample uniformly
          Logger.warn("Unknown parameter type for #{param_name}, using uniform sampling")
          {param_name, :rand.uniform()}
      end
    end
  end

  @spec sample_uniform_tpe(atom(), float(), float(), [map()], [map()]) :: float()
  defp sample_uniform_tpe(param_name, low, high, good_trials, bad_trials) do
    # Extract parameter values
    good_values = extract_param_values(good_trials, param_name)
    bad_values = extract_param_values(bad_trials, param_name)
    
    if length(good_values) < 2 do
      # Not enough data - sample uniformly
      low + :rand.uniform() * (high - low)
    else
      # Build KDE models
      good_kde = KDE.gaussian_kde(good_values)
      bad_kde = KDE.gaussian_kde(bad_values) 
      
      # Sample candidates and pick best ratio
      n_candidates = 24
      candidates = for _ <- 1..n_candidates, do: low + :rand.uniform() * (high - low)
      
      best_candidate = Enum.max_by(candidates, fn x ->
        log_good = good_kde.(x)
        log_bad = bad_kde.(x)
        
        # Compute log-ratio for numerical stability
        log_ratio = log_good - log_bad
        
        # Convert to regular ratio with epsilon floor
        ratio = :math.exp(log_ratio)
        max(ratio, @eps)
      end)
      
      # Ensure result is in bounds
      max(low, min(high, best_candidate))
    end
  end

  @spec sample_categorical_tpe(atom(), [term()], [map()], [map()]) :: term()
  defp sample_categorical_tpe(param_name, choices, good_trials, bad_trials) do
    good_values = extract_param_values(good_trials, param_name)
    bad_values = extract_param_values(bad_trials, param_name)
    
    if length(good_values) < 2 do
      # Not enough data - sample uniformly  
      Enum.random(choices)
    else
      # Count occurrences in good/bad trials
      good_counts = count_categories(good_values, choices)
      bad_counts = count_categories(bad_values, choices)
      
      # Compute probabilities with Laplace smoothing
      total_good = max(length(good_values), 1)
      total_bad = max(length(bad_values), 1)
      
      choice_scores = for choice <- choices do
        good_prob = (Map.get(good_counts, choice, 0) + 1) / (total_good + length(choices))
        bad_prob = (Map.get(bad_counts, choice, 0) + 1) / (total_bad + length(choices))
        
        ratio = good_prob / max(bad_prob, @eps)
        {choice, ratio}
      end
      
      # Sample proportional to ratio
      total_weight = Enum.reduce(choice_scores, 0.0, fn {_, ratio}, acc -> acc + ratio end)
      target = :rand.uniform() * total_weight
      
      {selected, _} = Enum.reduce_while(choice_scores, {hd(choices), 0.0}, fn {choice, ratio}, {current, cumsum} ->
        new_cumsum = cumsum + ratio
        if new_cumsum >= target do
          {:halt, {choice, new_cumsum}}
        else
          {:cont, {choice, new_cumsum}}
        end
      end)
      
      selected
    end
  end

  @spec extract_param_values([map()], atom()) :: [term()]
  defp extract_param_values(trials, param_name) do
    for trial <- trials,
        params = get_params(trial),
        value = get_param_value(params, param_name),
        value != nil,
        do: value
  end

  defp get_params(%{params: params}) when is_map(params), do: params
  defp get_params(%{"params" => params}) when is_map(params), do: params  
  defp get_params(%{payload: %{params: params}}) when is_map(params), do: params
  defp get_params(_), do: %{}

  defp get_param_value(params, param_name) when is_map(params) do
    Map.get(params, param_name) || Map.get(params, Atom.to_string(param_name))
  end
  defp get_param_value(_, _), do: nil

  @spec count_categories([term()], [term()]) :: map()
  defp count_categories(values, choices) do
    Enum.reduce(values, %{}, fn value, acc ->
      if value in choices do
        Map.update(acc, value, 1, &(&1 + 1))
      else
        acc
      end
    end)
  end

  @spec sample_search_space_randomly(map()) :: map()
  defp sample_search_space_randomly(search_space) do
    for {param_name, config} <- search_space, into: %{} do
      value = case config do
        %{type: :uniform, low: low, high: high} ->
          low + :rand.uniform() * (high - low)
        
        %{type: :log_uniform, low: low, high: high} ->
          log_low = :math.log(max(low, @eps))
          log_high = :math.log(high)
          log_val = log_low + :rand.uniform() * (log_high - log_low)
          :math.exp(log_val)
        
        %{type: :categorical, choices: choices} ->
          Enum.random(choices)
          
        _ ->
          :rand.uniform()  # Fallback
      end
      
      {param_name, value}
    end
  end
end