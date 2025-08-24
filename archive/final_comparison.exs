#\!/usr/bin/env elixir

Code.require_file("lib/scout/search_space.ex")
Code.require_file("lib/scout/sampler/random_search.ex") 
Code.require_file("lib/scout/sampler/tpe.ex")

defmodule FinalComparison do
  def ml_objective(params) do
    learning_rate = params[:learning_rate] || 0.1
    max_depth = params[:max_depth] || 6
    n_estimators = params[:n_estimators] || 100
    subsample = params[:subsample] || 1.0
    colsample_bytree = params[:colsample_bytree] || 1.0
    
    lr_score = -abs(:math.log10(learning_rate) + 1.0)
    depth_score = -abs(max_depth - 6) * 0.05
    n_est_score = -abs(n_estimators - 100) * 0.001
    subsample_score = -abs(subsample - 0.8) * 0.1
    colsample_score = -abs(colsample_bytree - 0.8) * 0.1
    
    0.8 + lr_score + depth_score + n_est_score + subsample_score + colsample_score
  end
  
  def rastrigin_objective(params) do
    x = params[:x] || 0.0
    y = params[:y] || 0.0
    20 + x*x - 10*:math.cos(2*:math.pi*x) + y*y - 10*:math.cos(2*:math.pi*y)
  end
  
  def run_test(name, objective, search_space, goal, n_trials) do
    IO.puts("\n🔬 #{name}")
    state = Scout.Sampler.TPE.init(%{goal: goal})
    
    {_, best, _} = Enum.reduce(1..n_trials, {[], nil, nil}, fn i, {hist, best_val, best_p} ->
      {params, _} = Scout.Sampler.TPE.next(search_space, i, hist, state)
      score = objective.(params)
      
      trial = %{
        id: "trial-#{i}",
        params: params,
        score: score,
        status: :succeeded
      }
      
      {new_best, new_params} = case goal do
        :maximize when best_val == nil or score > best_val -> {score, params}
        :minimize when best_val == nil or score < best_val -> {score, params}
        _ -> {best_val, best_p}
      end
      
      if rem(i, 10) == 0, do: IO.write(".")
      
      {hist ++ [trial], new_best, new_params}
    end)
    
    IO.puts("")
    IO.puts("  Scout (fixed): #{Float.round(best, 6)}")
    best
  end
end

IO.puts("""
╔═══════════════════════════════════════════════════════════════════╗
║                    FINAL COMPARISON RESULTS                       ║
╚═══════════════════════════════════════════════════════════════════╝
""")

# ML test
ml_space = fn _ -> %{
  learning_rate: {:log_uniform, 0.001, 0.3},
  max_depth: {:int, 3, 10},
  n_estimators: {:int, 50, 300},
  subsample: {:uniform, 0.5, 1.0},
  colsample_bytree: {:uniform, 0.5, 1.0}
} end

ml_result = FinalComparison.run_test(
  "ML Hyperparameters",
  &FinalComparison.ml_objective/1,
  ml_space,
  :maximize,
  30
)

IO.puts("  Scout (before): 0.510")  
IO.puts("  Optuna:        0.733")

# Rastrigin test
rastrigin_space = fn _ -> %{
  x: {:uniform, -5.12, 5.12},
  y: {:uniform, -5.12, 5.12}
} end

rastrigin_result = FinalComparison.run_test(
  "Rastrigin Benchmark", 
  &FinalComparison.rastrigin_objective/1,
  rastrigin_space,
  :minimize,
  50
)

IO.puts("  Scout (before): 6.180")
IO.puts("  Optuna:        2.280")

IO.puts("\n📊 IMPROVEMENT ANALYSIS:")
ml_improvement = ((ml_result - 0.510) / 0.510 * 100)
rastrigin_improvement = ((6.180 - rastrigin_result) / 6.180 * 100)

IO.puts("  ML improvement: #{Float.round(ml_improvement, 1)}%")
IO.puts("  Rastrigin improvement: #{Float.round(rastrigin_improvement, 1)}%")

ml_gap = abs(ml_result - 0.733) / 0.733 * 100
rastrigin_gap = abs(rastrigin_result - 2.280) / 2.280 * 100

IO.puts("\n📈 PARITY WITH OPTUNA:")
IO.puts("  ML gap: #{Float.round(ml_gap, 1)}%")
IO.puts("  Rastrigin gap: #{Float.round(rastrigin_gap, 1)}%")
IO.puts("  Average gap: #{Float.round((ml_gap + rastrigin_gap) / 2, 1)}%")
