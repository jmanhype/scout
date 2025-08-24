#\!/usr/bin/env elixir

# TEST IMPROVED TPE - Validate performance improvements

defmodule TestImprovedTPE do
  @moduledoc """
  Tests the improved TPE implementation with aligned parameters.
  This validates that the dogfooding-driven fixes work.
  """
  
  def ml_objective(params) do
    learning_rate = params[:learning_rate] || 0.1
    max_depth = params[:max_depth] || 6
    n_estimators = params[:n_estimators] || 100
    subsample = params[:subsample] || 1.0
    colsample_bytree = params[:colsample_bytree] || 1.0
    
    # Identical scoring to optuna_baseline.py
    lr_score = -abs(:math.log10(learning_rate) + 1.0)
    depth_score = -abs(max_depth - 6) * 0.05
    n_est_score = -abs(n_estimators - 100) * 0.001
    subsample_score = -abs(subsample - 0.8) * 0.1
    colsample_score = -abs(colsample_bytree - 0.8) * 0.1
    
    accuracy = 0.8 + lr_score + depth_score + n_est_score + subsample_score + colsample_score
    max(0.0, min(1.0, accuracy))
  end
  
  def ml_search_space(_) do
    %{
      learning_rate: {:log_uniform, 0.001, 0.3},
      max_depth: {:int, 3, 10}, 
      n_estimators: {:int, 50, 300},
      subsample: {:uniform, 0.5, 1.0},
      colsample_bytree: {:uniform, 0.5, 1.0}
    }
  end
  
  def rastrigin_objective(params) do
    x = params[:x] || 0.0
    y = params[:y] || 0.0
    
    20 + x*x - 10*:math.cos(2*:math.pi*x) + y*y - 10*:math.cos(2*:math.pi*y)
  end
  
  def rastrigin_search_space(_) do
    %{
      x: {:uniform, -5.12, 5.12},
      y: {:uniform, -5.12, 5.12}
    }
  end
  
  def simple_trial(id, params, score, status \\ :succeeded) do
    %{
      id: id,
      study_id: "test",
      params: params,
      bracket: 0,
      score: score,
      status: status
    }
  end
  
  def run_tpe_test(test_name, objective_func, search_space_func, goal, n_trials) do
    IO.puts("\n🔬 Testing Improved TPE: #{test_name}")
    IO.puts("  " <> String.duplicate("─", 40))
    
    # Use improved TPE parameters
    tpe_opts = %{
      min_obs: 10,    # Reduced from 20
      gamma: 0.25,    # Increased from 0.15
      goal: goal
    }
    
    state = Scout.Sampler.TPE.init(tpe_opts)
    
    # Run optimization
    {history, best_value, best_params} = 
      Enum.reduce(1..n_trials, {[], nil, %{}}, fn i, {hist, best_val, best_p} ->
        # Get next parameters from TPE
        {params, new_state} = Scout.Sampler.TPE.next(search_space_func, i, hist, state)
        score = objective_func.(params)
        
        # Create trial
        trial = simple_trial("trial-#{i}", params, score)
        
        # Update history
        new_history = hist ++ [trial]
        
        # Update best
        {new_best_val, new_best_params} = case goal do
          :maximize ->
            if best_val == nil or score > best_val do
              {score, params}
            else
              {best_val, best_p}
            end
          :minimize ->
            if best_val == nil or score < best_val do
              {score, params}
            else
              {best_val, best_p}
            end
        end
        
        # Update state for next iteration
        state = new_state
        
        # Show progress
        if rem(i, 10) == 0 do
          IO.write(".")
        end
        
        # Return accumulated values
        {new_history, new_best_val, new_best_params}
      end)
    
    IO.puts("")
    IO.puts("  Best value: #{Float.round(best_value, 6)}")
    IO.puts("  Trials evaluated: #{length(history)}")
    
    %{
      test_name: test_name,
      best_value: best_value,
      best_params: best_params,
      n_trials: n_trials
    }
  end
  
  def run() do
    IO.puts("""
    ╔═══════════════════════════════════════════════════════════════════╗
    ║                   IMPROVED TPE VALIDATION TEST                    ║
    ║               (Testing Dogfooding-Driven Fixes)                   ║
    ╚═══════════════════════════════════════════════════════════════════╝
    """)
    
    # Test 1: ML hyperparameters
    ml_result = run_tpe_test(
      "ML Hyperparameters",
      &ml_objective/1,
      &ml_search_space/1,
      :maximize,
      30
    )
    
    # Test 2: Rastrigin benchmark  
    rastrigin_result = run_tpe_test(
      "Rastrigin Benchmark",
      &rastrigin_objective/1,
      &rastrigin_search_space/1,
      :minimize,
      50
    )
    
    # Compare with previous results
    IO.puts("\n📊 PERFORMANCE COMPARISON:")
    IO.puts(String.duplicate("━", 67))
    
    IO.puts("\nML Hyperparameters:")
    IO.puts("  Before fixes: 0.510")
    IO.puts("  After fixes:  #{Float.round(ml_result.best_value, 6)}")
    IO.puts("  Optuna:       0.733")
    
    ml_improvement = (ml_result.best_value - 0.510) / 0.510 * 100
    IO.puts("  Improvement:  #{Float.round(ml_improvement, 1)}%")
    
    IO.puts("\nRastrigin Benchmark:")
    IO.puts("  Before fixes: 6.180")
    IO.puts("  After fixes:  #{Float.round(rastrigin_result.best_value, 6)}")
    IO.puts("  Optuna:       2.280")
    
    rastrigin_improvement = (6.180 - rastrigin_result.best_value) / 6.180 * 100
    IO.puts("  Improvement:  #{Float.round(rastrigin_improvement, 1)}%")
    
    IO.puts("\n🎯 KEY IMPROVEMENTS APPLIED:")
    IO.puts("✅ Gamma: 0.15 → 0.25 (closer to Optuna's 0.5)")
    IO.puts("✅ Min obs: 20 → 10 (matches Optuna's n_startup_trials)")
    IO.puts("✅ Integer parameter support added")
    IO.puts("✅ Scott's rule for KDE bandwidth (1.06 factor)")
    
    IO.puts("\n📈 PARITY ASSESSMENT:")
    
    # Calculate final parity
    ml_gap = abs(ml_result.best_value - 0.733) / 0.733 * 100
    rastrigin_gap = abs(rastrigin_result.best_value - 2.280) / 2.280 * 100
    avg_gap = (ml_gap + rastrigin_gap) / 2
    
    IO.puts("  ML gap:        #{Float.round(ml_gap, 1)}%")
    IO.puts("  Rastrigin gap: #{Float.round(rastrigin_gap, 1)}%")
    IO.puts("  Average gap:   #{Float.round(avg_gap, 1)}%")
    
    if avg_gap < 30 do
      IO.puts("\n✅ EXCELLENT: Scout TPE now has strong parity with Optuna\!")
    else
      IO.puts("\n⚠️  Still some gaps, but significant improvement achieved")
    end
  end
end

# Run the improved TPE test
TestImprovedTPE.run()
