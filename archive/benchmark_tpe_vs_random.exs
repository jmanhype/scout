#!/usr/bin/env elixir

# Comprehensive benchmark: TPE vs Random Search
{:ok, _} = Application.ensure_all_started(:scout)

defmodule Benchmark do
  def rosenbrock(params) do
    # Rosenbrock function - harder optimization problem
    x = params.x
    y = params.y
    score = -((1 - x) ** 2 + 100 * (y - x ** 2) ** 2)
    {:ok, score}
  end
  
  def ackley(params) do
    # Ackley function - many local minima
    x = params.x
    y = params.y
    term1 = -20 * :math.exp(-0.2 * :math.sqrt(0.5 * (x*x + y*y)))
    term2 = -:math.exp(0.5 * (:math.cos(2*:math.pi()*x) + :math.cos(2*:math.pi()*y)))
    score = -(term1 + term2 + :math.exp(1) + 20)
    {:ok, score}
  end
  
  def quadratic(params) do
    # Simple quadratic - easy optimization
    x = params.x - 2.0
    y = params.y - 2.0
    score = -(x*x + y*y)
    {:ok, score}
  end
  
  def search_space(_) do
    %{
      x: {:uniform, -5.0, 5.0},
      y: {:uniform, -5.0, 5.0}
    }
  end
  
  def run_optimization(sampler_type, objective_fn, n_trials, run_id) do
    # Initialize sampler
    sampler_state = case sampler_type do
      :tpe -> 
        Scout.Sampler.TPE.init(%{
          min_obs: 10,
          gamma: 0.15,
          n_candidates: 24,
          goal: :maximize
        })
      :random ->
        Scout.Sampler.RandomSearch.init(%{})
    end
    
    history = []
    best_score = -999999
    scores = []
    
    final_best = Enum.reduce(1..n_trials, {best_score, history, sampler_state, scores}, fn i, {current_best, hist, state, score_list} ->
      # Get next parameters
      {params, new_state} = case sampler_type do
        :tpe -> Scout.Sampler.TPE.next(&search_space/1, i, hist, state)
        :random -> Scout.Sampler.RandomSearch.next(&search_space/1, i, hist, state)
      end
      
      # Evaluate
      {:ok, score} = objective_fn.(params)
      new_scores = score_list ++ [score]
      
      # Update history
      trial = %Scout.Trial{
        id: "trial-#{run_id}-#{i}",
        study_id: "benchmark-#{run_id}",
        params: params,
        bracket: 0,
        score: score,
        status: :succeeded
      }
      new_history = hist ++ [trial]
      
      # Track best
      new_best = if score > current_best, do: score, else: current_best
      
      {new_best, new_history, new_state, new_scores}
    end)
    
    {best, _, _, all_scores} = final_best
    {best, all_scores}
  end
  
  def calculate_stats(scores) do
    n = length(scores)
    mean = Enum.sum(scores) / n
    variance = Enum.reduce(scores, 0.0, fn x, acc -> 
      acc + :math.pow(x - mean, 2) 
    end) / n
    std = :math.sqrt(variance)
    {mean, std, Enum.max(scores), Enum.min(scores)}
  end
  
  def compare_convergence(tpe_scores, random_scores, window_size \\ 10) do
    # Compare convergence rates
    tpe_windows = Enum.chunk_every(tpe_scores, window_size)
    random_windows = Enum.chunk_every(random_scores, window_size)
    
    tpe_means = Enum.map(tpe_windows, &(Enum.sum(&1) / length(&1)))
    random_means = Enum.map(random_windows, &(Enum.sum(&1) / length(&1)))
    
    # Calculate improvement over windows
    tpe_improvement = if length(tpe_means) > 1 do
      first = hd(tpe_means)
      last = List.last(tpe_means)
      if first < 0, do: (last - first) / abs(first) * 100, else: 0
    else
      0
    end
    
    random_improvement = if length(random_means) > 1 do
      first = hd(random_means)
      last = List.last(random_means)
      if first < 0, do: (last - first) / abs(first) * 100, else: 0
    else
      0
    end
    
    {tpe_improvement, random_improvement}
  end
end

# Run benchmark
IO.puts("🏁 SCOUT BENCHMARK: TPE vs Random Search")
IO.puts("=" <> String.duplicate("=", 59))
IO.puts("")

# Test functions
test_functions = [
  {:quadratic, &Benchmark.quadratic/1, "(2, 2)", 0.0},
  {:ackley, &Benchmark.ackley/1, "(0, 0)", 0.0},
  {:rosenbrock, &Benchmark.rosenbrock/1, "(1, 1)", 0.0}
]

n_trials = 100
n_runs = 3  # Multiple runs for statistical significance

results = Enum.map(test_functions, fn {name, func, optimum, optimal_value} ->
  IO.puts("📊 Testing #{String.upcase(Atom.to_string(name))} function")
  IO.puts("   Optimum: #{optimum}, Value: #{optimal_value}")
  IO.puts("")
  
  # Collect results from multiple runs
  tpe_results = for run <- 1..n_runs do
    {best, scores} = Benchmark.run_optimization(:tpe, func, n_trials, "tpe-#{name}-#{run}")
    {best, scores}
  end
  
  random_results = for run <- 1..n_runs do
    {best, scores} = Benchmark.run_optimization(:random, func, n_trials, "random-#{name}-#{run}")
    {best, scores}
  end
  
  # Calculate average best scores
  tpe_bests = Enum.map(tpe_results, fn {best, _} -> best end)
  random_bests = Enum.map(random_results, fn {best, _} -> best end)
  
  tpe_avg_best = Enum.sum(tpe_bests) / n_runs
  random_avg_best = Enum.sum(random_bests) / n_runs
  
  # Get convergence comparison from first run
  {_, tpe_scores_1} = hd(tpe_results)
  {_, random_scores_1} = hd(random_results)
  {tpe_imp, random_imp} = Benchmark.compare_convergence(tpe_scores_1, random_scores_1)
  
  # Display results
  IO.puts("   TPE Results:")
  IO.puts("   - Average best: #{Float.round(tpe_avg_best, 4)}")
  IO.puts("   - Best of all runs: #{Float.round(Enum.max(tpe_bests), 4)}")
  IO.puts("   - Convergence improvement: #{Float.round(tpe_imp, 1)}%")
  
  IO.puts("")
  IO.puts("   Random Search Results:")
  IO.puts("   - Average best: #{Float.round(random_avg_best, 4)}")
  IO.puts("   - Best of all runs: #{Float.round(Enum.max(random_bests), 4)}")
  IO.puts("   - Convergence improvement: #{Float.round(random_imp, 1)}%")
  
  IO.puts("")
  
  # Determine winner
  winner = if tpe_avg_best > random_avg_best do
    improvement = ((tpe_avg_best - random_avg_best) / abs(random_avg_best)) * 100
    IO.puts("   ✅ TPE wins by #{Float.round(improvement, 1)}%")
    :tpe
  else
    improvement = ((random_avg_best - tpe_avg_best) / abs(tpe_avg_best)) * 100
    IO.puts("   ⚠️  Random wins by #{Float.round(improvement, 1)}%")
    :random
  end
  
  IO.puts("")
  IO.puts("   " <> String.duplicate("-", 55))
  IO.puts("")
  
  {name, winner, tpe_avg_best, random_avg_best}
end)

# Summary
IO.puts("=" <> String.duplicate("=", 59))
IO.puts("📈 SUMMARY")
IO.puts("")

tpe_wins = Enum.count(results, fn {_, winner, _, _} -> winner == :tpe end)
random_wins = Enum.count(results, fn {_, winner, _, _} -> winner == :random end)

IO.puts("TPE won: #{tpe_wins}/#{length(results)} test functions")
IO.puts("Random won: #{random_wins}/#{length(results)} test functions")

IO.puts("")
if tpe_wins > random_wins do
  IO.puts("🏆 TPE demonstrates superior optimization performance!")
else
  if tpe_wins == random_wins do
    IO.puts("🤝 TPE and Random Search performed similarly")
  else
    IO.puts("⚠️  TPE needs further tuning for these problems")
  end
end

IO.puts("")
IO.puts("💡 Notes:")
IO.puts("- TPE excels with smooth functions and clear structure")
IO.puts("- Random can be competitive on highly multimodal landscapes")
IO.puts("- TPE's advantage grows with more trials and dimensions")