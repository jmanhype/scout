defmodule Scout.Sampler.ConditionalTPE do
  @behaviour Scout.Sampler
  @moduledoc """
  TPE sampler with support for conditional search spaces.
  
  This implementation handles conditional parameters where certain parameters
  only exist based on the values of other parameters. Similar to Optuna's
  TPESampler(group=True) option.
  
  Example:
    # If classifier is "SVM", suggest C parameter
    # If classifier is "RandomForest", suggest max_depth
  """
  
  def init(opts) do
    base_state = Scout.Sampler.TPE.init(opts)
    
    Map.merge(base_state, %{
      # Enable grouping for conditional parameters
      group: Map.get(opts, :group, true),
      # Track parameter dependencies
      param_groups: Map.get(opts, :param_groups, %{}),
      # Cache for conditional evaluations
      condition_cache: %{}
    })
  end
  
  def next(space_fun, ix, history, state) do
    spec = space_fun.(ix)
    
    if not state.group do
      # Fallback to regular TPE without conditional support
      Scout.Sampler.TPE.next(space_fun, ix, history, state)
    else
      # Handle conditional parameters
      sample_with_conditions(spec, history, state, space_fun, ix)
    end
  end
  
  # Sample parameters considering conditional dependencies
  defp sample_with_conditions(spec, history, state, space_fun, ix) do
    # Identify independent and conditional parameters
    {independent_params, conditional_params} = classify_parameters(spec)
    
    # First, sample independent parameters
    independent_values = sample_independent_params(
      independent_params, 
      history, 
      state,
      space_fun,
      ix
    )
    
    # Then, sample conditional parameters based on independent values
    conditional_values = sample_conditional_params(
      conditional_params,
      independent_values,
      history,
      state
    )
    
    # Combine all parameters
    all_params = Map.merge(independent_values, conditional_values)
    
    {all_params, state}
  end
  
  # Classify parameters into independent and conditional
  defp classify_parameters(spec) do
    Enum.reduce(spec, {%{}, %{}}, fn {key, value}, {indep, cond} ->
      case value do
        {:conditional, condition_fn, param_spec} ->
          {indep, Map.put(cond, key, {condition_fn, param_spec})}
        _ ->
          {Map.put(indep, key, value), cond}
      end
    end)
  end
  
  # Sample independent parameters using TPE
  defp sample_independent_params(params, history, state, space_fun, ix) do
    if map_size(params) == 0 do
      %{}
    else
      # Create a temporary spec with only independent params
      temp_spec_fun = fn _ -> params end
      
      # Use TPE to sample independent parameters
      {sampled, _} = Scout.Sampler.TPE.next(temp_spec_fun, ix, history, state)
      sampled
    end
  end
  
  # Sample conditional parameters based on conditions
  defp sample_conditional_params(conditional_params, independent_values, history, state) do
    Enum.reduce(conditional_params, %{}, fn {key, {condition_fn, param_spec}}, acc ->
      # Check if condition is met
      if condition_fn.(independent_values) do
        # Condition is true, sample this parameter
        value = sample_single_conditional_param(
          key,
          param_spec,
          independent_values,
          history,
          state
        )
        Map.put(acc, key, value)
      else
        # Condition is false, skip this parameter
        acc
      end
    end)
  end
  
  # Sample a single conditional parameter
  defp sample_single_conditional_param(key, param_spec, parent_values, history, state) do
    # Filter history to only include trials with matching parent values
    filtered_history = filter_history_by_parents(history, parent_values)
    
    if length(filtered_history) < state.min_obs do
      # Not enough data, sample randomly
      sample_random(param_spec)
    else
      # Use TPE on filtered history
      sample_with_tpe(key, param_spec, filtered_history, state)
    end
  end
  
  # Filter history to trials with matching parent parameter values
  defp filter_history_by_parents(history, parent_values) do
    Enum.filter(history, fn trial ->
      Enum.all?(parent_values, fn {key, value} ->
        Map.get(trial.params, key) == value
      end)
    end)
  end
  
  # Random sampling for a parameter
  defp sample_random(param_spec) do
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
  
  # Sample using TPE on filtered history
  defp sample_with_tpe(key, param_spec, filtered_history, state) do
    # Build distributions from filtered history
    obs = for t <- filtered_history, 
             is_number(t.score),
             Map.has_key?(t.params, key),
             do: {Map.get(t.params, key), t.score}
    
    if obs == [] do
      sample_random(param_spec)
    else
      # Split into good and bad
      sorted = case state.goal do
        :minimize -> Enum.sort_by(obs, fn {_p, s} -> s end, :asc)
        _ -> Enum.sort_by(obs, fn {_p, s} -> s end, :desc)
      end
      
      n = length(sorted)
      n_good = max(trunc(state.gamma * n), 1)
      {good, bad} = Enum.split(sorted, n_good)
      
      # Sample from good distribution
      good_values = Enum.map(good, fn {v, _} -> v end)
      
      if good_values == [] do
        sample_random(param_spec)
      else
        # Use KDE to sample
        sample_from_kde(good_values, param_spec)
      end
    end
  end
  
  # Sample from KDE built from good values
  defp sample_from_kde(values, param_spec) do
    # Simple KDE sampling: pick a random value and add noise
    base = Enum.random(values)
    
    case param_spec do
      {:uniform, min, max} ->
        bandwidth = (max - min) * 0.1
        value = base + :rand.normal() * bandwidth
        max(min, min(max, value))
      {:log_uniform, min, max} ->
        log_base = :math.log(base)
        log_min = :math.log(min)
        log_max = :math.log(max)
        bandwidth = (log_max - log_min) * 0.1
        log_value = log_base + :rand.normal() * bandwidth
        :math.exp(max(log_min, min(log_max, log_value)))
      {:int, min, max} ->
        bandwidth = max((max - min) * 0.1, 1.0)
        value = base + round(:rand.normal() * bandwidth)
        max(min, min(max, value))
      {:choice, choices} ->
        # For categorical, use frequency-based sampling
        freq = Enum.frequencies(values)
        total = Enum.sum(Map.values(freq))
        r = :rand.uniform() * total
        
        {selected, _} = Enum.reduce_while(freq, {nil, 0}, fn {choice, count}, {_, cum} ->
          new_cum = cum + count
          if new_cum >= r do
            {:halt, {choice, new_cum}}
          else
            {:cont, {choice, new_cum}}
          end
        end)
        
        selected || Enum.random(choices)
      _ ->
        base
    end
  end
end

defmodule Scout.ConditionalSpace do
  @moduledoc """
  Helper module for defining conditional search spaces.
  
  Example usage:
    
    def search_space(_) do
      %{
        classifier: {:choice, ["SVM", "RandomForest", "XGBoost"]},
        # SVM-specific parameters
        svm_c: Scout.ConditionalSpace.conditional(
          fn params -> params.classifier == "SVM" end,
          {:log_uniform, 0.001, 1000}
        ),
        svm_kernel: Scout.ConditionalSpace.conditional(
          fn params -> params.classifier == "SVM" end,
          {:choice, ["rbf", "linear", "poly"]}
        ),
        # RandomForest-specific parameters
        rf_max_depth: Scout.ConditionalSpace.conditional(
          fn params -> params.classifier == "RandomForest" end,
          {:int, 2, 32}
        ),
        rf_n_estimators: Scout.ConditionalSpace.conditional(
          fn params -> params.classifier == "RandomForest" end,
          {:int, 10, 200}
        ),
        # XGBoost-specific parameters
        xgb_learning_rate: Scout.ConditionalSpace.conditional(
          fn params -> params.classifier == "XGBoost" end,
          {:log_uniform, 0.01, 0.3}
        ),
        xgb_max_depth: Scout.ConditionalSpace.conditional(
          fn params -> params.classifier == "XGBoost" end,
          {:int, 3, 10}
        )
      }
    end
  """
  
  @doc """
  Define a conditional parameter that only exists when condition is met.
  """
  def conditional(condition_fn, param_spec) do
    {:conditional, condition_fn, param_spec}
  end
  
  @doc """
  Check if a parameter value meets its condition.
  """
  def is_active?(condition_fn, params) do
    condition_fn.(params)
  end
  
  @doc """
  Filter parameters to only include active ones based on conditions.
  """
  def filter_active_params(spec, current_params) do
    Enum.reduce(spec, %{}, fn {key, value}, acc ->
      case value do
        {:conditional, condition_fn, _param_spec} ->
          if condition_fn.(current_params) do
            Map.put(acc, key, Map.get(current_params, key))
          else
            acc
          end
        _ ->
          Map.put(acc, key, Map.get(current_params, key))
      end
    end)
  end
end