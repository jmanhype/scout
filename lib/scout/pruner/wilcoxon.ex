defmodule Scout.Pruner.WilcoxonPruner do
  @moduledoc """
  Prunes trials using the Wilcoxon signed-rank test for statistical significance.
  
  Equivalent to Optuna's WilcoxonPruner. Uses non-parametric statistical testing
  to determine if a trial is significantly worse than the best trial.
  """
  
  @behaviour Scout.Pruner

  # Default implementation for missing callbacks
  def assign_bracket(_trial_index, state), do: {0, state}
  def keep?(_study_id, _trial_id, _bracket, _step, state), do: {true, state}
  
  @default_p_threshold 0.1
  @default_n_startup_trials 10
  @default_n_min_trials 4
  
  def init(opts \\ %{}) do
    %{
      p_threshold: Map.get(opts, :p_threshold, @default_p_threshold),
      n_startup_trials: Map.get(opts, :n_startup_trials, @default_n_startup_trials),
      n_min_trials: Map.get(opts, :n_min_trials, @default_n_min_trials)
    }
  end
  
  def should_prune?(study_id, _trial_id, step, value, state) do
    # Get completed trials
    completed_trials = Scout.Store.list_trials(study_id)
    |> Enum.filter(&(&1.status == :completed))
    
    # Don't prune if not enough startup trials
    if length(completed_trials) < state.n_startup_trials do
      {false, state}
    else
      # Find the best completed trial
      best_trial = find_best_trial(completed_trials)
      
      if best_trial == nil do
        {false, state}
      else
        # Get intermediate values for best trial up to current step
        best_values = get_intermediate_values_up_to(best_trial, step)
        
        # Get intermediate values for current trial up to current step
        current_trial = %{intermediate_values: %{step => value}}
        current_values = get_intermediate_values_up_to(current_trial, step)
        
        # Need minimum number of observations for statistical test
        if length(best_values) < state.n_min_trials or length(current_values) < state.n_min_trials do
          {false, state}
        else
          # Perform Wilcoxon signed-rank test
          p_value = wilcoxon_signed_rank_test(current_values, best_values)
          
          # Prune if current is significantly worse than best
          should_prune = p_value < state.p_threshold and mean(current_values) > mean(best_values)
          {should_prune, state}
        end
      end
    end
  end
  
  defp find_best_trial(trials) do
    trials
    |> Enum.filter(&(&1.score != nil))
    |> Enum.min_by(&(&1.score), fn -> nil end)
  end
  
  defp get_intermediate_values_up_to(trial, max_step) do
    trial.intermediate_values
    |> Enum.filter(fn {step, _value} -> step <= max_step end)
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.map(&elem(&1, 1))
  end
  
  defp mean(values) do
    if length(values) == 0 do
      0
    else
      Enum.sum(values) / length(values)
    end
  end
  
  @doc """
  Implements the Wilcoxon signed-rank test.
  
  Returns p-value for the null hypothesis that the two samples come from
  the same distribution.
  """
  def wilcoxon_signed_rank_test(sample1, sample2) when length(sample1) != length(sample2) do
    # Samples must have same length for paired test
    # Pad shorter sample with its mean
    n1 = length(sample1)
    n2 = length(sample2)
    
    {s1, s2} = cond do
      n1 < n2 ->
        mean1 = mean(sample1)
        padded = sample1 ++ List.duplicate(mean1, n2 - n1)
        {padded, sample2}
      n1 > n2 ->
        mean2 = mean(sample2)
        padded = sample2 ++ List.duplicate(mean2, n1 - n2)
        {sample1, padded}
      true ->
        {sample1, sample2}
    end
    
    wilcoxon_signed_rank_test_impl(s1, s2)
  end
  
  def wilcoxon_signed_rank_test(sample1, sample2) do
    wilcoxon_signed_rank_test_impl(sample1, sample2)
  end
  
  defp wilcoxon_signed_rank_test_impl(sample1, sample2) do
    # Calculate differences
    differences = Enum.zip(sample1, sample2)
    |> Enum.map(fn {x, y} -> x - y end)
    |> Enum.filter(&(&1 != 0))  # Remove zero differences
    
    n = length(differences)
    
    if n == 0 do
      # No differences, samples are identical
      1.0
    else
      # Rank absolute differences
      ranked = differences
      |> Enum.map(&{&1, abs(&1)})
      |> Enum.sort_by(&elem(&1, 1))
      |> Enum.with_index(1)
      |> Enum.map(fn {{diff, _abs}, rank} -> {diff, rank} end)
      
      # Handle ties by averaging ranks
      ranked_with_ties = handle_ties(ranked)
      
      # Calculate W+ (sum of positive ranks) and W- (sum of negative ranks)
      {w_plus, w_minus} = ranked_with_ties
      |> Enum.reduce({0, 0}, fn {diff, rank}, {wp, wm} ->
        if diff > 0 do
          {wp + rank, wm}
        else
          {wp, wm + rank}
        end
      end)
      
      # Use smaller of W+ and W-
      w = min(w_plus, w_minus)
      
      # Calculate z-score for normal approximation (valid for n > 10)
      if n > 10 do
        # Normal approximation
        mean_w = n * (n + 1) / 4
        var_w = n * (n + 1) * (2 * n + 1) / 24
        
        # Continuity correction
        z = (w + 0.5 - mean_w) / :math.sqrt(var_w)
        
        # Two-tailed p-value using normal CDF approximation
        p_value = 2 * normal_cdf(-abs(z))
        p_value
      else
        # For small samples, use exact critical values
        # This is a simplified approximation
        critical_value = get_wilcoxon_critical_value(n)
        if w <= critical_value do
          0.05  # Significant at 5% level
        else
          0.5   # Not significant
        end
      end
    end
  end
  
  defp handle_ties(ranked_diffs) do
    # Group by absolute value to find ties
    grouped = Enum.group_by(ranked_diffs, fn {diff, _rank} -> abs(diff) end)
    
    Enum.flat_map(grouped, fn {_abs_val, group} ->
      if length(group) > 1 do
        # Average ranks for tied values
        ranks = Enum.map(group, &elem(&1, 1))
        avg_rank = Enum.sum(ranks) / length(ranks)
        Enum.map(group, fn {diff, _} -> {diff, avg_rank} end)
      else
        group
      end
    end)
  end
  
  defp normal_cdf(z) do
    # Approximation of normal CDF using error function
    0.5 * (1 + erf(z / :math.sqrt(2)))
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
  
  defp get_wilcoxon_critical_value(n) do
    # Critical values for Wilcoxon test at 5% significance level (two-tailed)
    # These are approximate values for small samples
    critical_values = %{
      5 => 0,
      6 => 2,
      7 => 3,
      8 => 5,
      9 => 8,
      10 => 10
    }
    
    Map.get(critical_values, n, div(n * (n + 1), 4) - 1.96 * :math.sqrt(n * (n + 1) * (2 * n + 1) / 24))
  end
  
  @doc """
  Performs a simple rank-sum test as an alternative.
  """
  def rank_sum_test(sample1, sample2) do
    # Combine samples with labels
    combined = (Enum.map(sample1, &{&1, :sample1}) ++ Enum.map(sample2, &{&1, :sample2}))
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.with_index(1)
    
    # Calculate rank sum for sample1
    rank_sum1 = combined
    |> Enum.filter(fn {{_, label}, _} -> label == :sample1 end)
    |> Enum.map(&elem(&1, 1))
    |> Enum.sum()
    
    n1 = length(sample1)
    n2 = length(sample2)
    
    # Calculate U statistic
    u1 = rank_sum1 - n1 * (n1 + 1) / 2
    u2 = n1 * n2 - u1
    u = min(u1, u2)
    
    # Normal approximation for p-value
    mean_u = n1 * n2 / 2
    var_u = n1 * n2 * (n1 + n2 + 1) / 12
    z = (u - mean_u) / :math.sqrt(var_u)
    
    2 * normal_cdf(-abs(z))
  end
end