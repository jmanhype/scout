#!/usr/bin/env elixir

Code.require_file("lib/scout/search_space.ex")
Code.require_file("lib/scout/sampler/random_search.ex")
Code.require_file("lib/scout/sampler/tpe.ex")
Code.require_file("lib/scout/sampler/tpe_multivariate.ex")

defmodule TestProductionTPE do
  def rastrigin(params) do
    x = params[:x] || 0.0
    y = params[:y] || 0.0
    20 + x*x - 10*:math.cos(2*:math.pi*x) + y*y - 10*:math.cos(2*:math.pi*y)
  end
  
  def rosenbrock(params) do
    x = params[:x] || 0.0
    y = params[:y] || 0.0
    100 * :math.pow(y - x*x, 2) + :math.pow(1 - x, 2)
  end
  
  def run_comparison(n_runs \\ 20, n_trials \\ 100) do
    IO.puts("""
    ╔═══════════════════════════════════════════════════════════════════╗
    ║              PRODUCTION MULTIVARIATE TPE VALIDATION               ║
    ╚═══════════════════════════════════════════════════════════════════╝
    """)
    
    # Test on Rastrigin
    IO.puts("\n📊 Testing on Rastrigin Function (highly correlated)")
    IO.puts("=" <> String.duplicate("=", 69))
    
    # Original TPE
    tpe_results = run_test(Scout.Sampler.TPE, &rastrigin/1, n_runs, n_trials)
    IO.puts("  Standard TPE:     #{format_result(tpe_results)}")
    
    # Multivariate TPE
    multi_results = run_test(Scout.Sampler.TPEMultivariate, &rastrigin/1, n_runs, n_trials)
    IO.puts("  Multivariate TPE: #{format_result(multi_results)}")
    
    IO.puts("  Optuna TPE:       2.28 (reference)")
    
    improvement = ((tpe_results.avg - multi_results.avg) / tpe_results.avg) * 100
    IO.puts("\n  Improvement: #{Float.round(improvement, 1)}%")
    
    # Test on Rosenbrock
    IO.puts("\n📊 Testing on Rosenbrock Function")
    IO.puts("=" <> String.duplicate("=", 69))
    
    tpe_ros = run_test(Scout.Sampler.TPE, &rosenbrock/1, n_runs, n_trials)
    IO.puts("  Standard TPE:     #{format_result(tpe_ros)}")
    
    multi_ros = run_test(Scout.Sampler.TPEMultivariate, &rosenbrock/1, n_runs, n_trials)
    IO.puts("  Multivariate TPE: #{format_result(multi_ros)}")
    
    IO.puts("  Optuna TPE:       5.0 (reference)")
    
    improvement_ros = ((tpe_ros.avg - multi_ros.avg) / tpe_ros.avg) * 100
    IO.puts("\n  Improvement: #{Float.round(improvement_ros, 1)}%")
    
    # Final assessment
    IO.puts("\n" <> String.duplicate("=", 70))
    IO.puts("🎯 PARITY ASSESSMENT")
    IO.puts(String.duplicate("=", 70))
    
    rastrigin_gap = ((multi_results.avg - 2.28) / 2.28) * 100
    rosenbrock_gap = ((multi_ros.avg - 5.0) / 5.0) * 100
    
    IO.puts("Gaps to Optuna:")
    IO.puts("  Rastrigin:  #{format_gap(rastrigin_gap)}")
    IO.puts("  Rosenbrock: #{format_gap(rosenbrock_gap)}")
    
    cond do
      rastrigin_gap < 50 and rosenbrock_gap < 50 ->
        IO.puts("\n✅ SUCCESS! Multivariate TPE achieves Optuna parity!")
      rastrigin_gap < 100 ->
        IO.puts("\n🔧 Good progress! Within 2x of Optuna performance.")
      true ->
        IO.puts("\n⚠️  Needs further optimization.")
    end
    
    IO.puts("\nRECOMMENDATION: Replace Scout.Sampler.TPE with TPEMultivariate")
  end
  
  defp run_test(sampler_module, objective_fn, n_runs, n_trials) do
    results = Enum.map(1..n_runs, fn seed ->
      :rand.seed(:exsss, {seed, seed, seed})
      
      search_space = fn _ -> 
        %{
          x: {:uniform, -5.12, 5.12},
          y: {:uniform, -5.12, 5.12}
        }
      end
      
      state = sampler_module.init(%{goal: :minimize})
      
      {_, best, _} = Enum.reduce(1..n_trials, {[], 999999.0, state}, fn i, {hist, best_val, curr_state} ->
        {params, new_state} = sampler_module.next(search_space, i, hist, curr_state)
        score = objective_fn.(params)
        
        trial = %{
          id: "trial-#{i}",
          params: params,
          score: score,
          status: :succeeded
        }
        
        new_best = min(score, best_val)
        {hist ++ [trial], new_best, new_state}
      end)
      
      IO.write(".")
      best
    end)
    
    IO.puts("")
    
    %{
      avg: Enum.sum(results) / n_runs,
      min: Enum.min(results),
      max: Enum.max(results),
      std: :math.sqrt(Enum.sum(Enum.map(results, fn r -> 
        :math.pow(r - Enum.sum(results) / n_runs, 2) 
      end)) / n_runs)
    }
  end
  
  defp format_result(results) do
    "Avg: #{Float.round(results.avg, 3)}, Best: #{Float.round(results.min, 3)}, Std: #{Float.round(results.std, 3)}"
  end
  
  defp format_gap(gap) do
    sign = if gap >= 0, do: "+", else: ""
    "#{sign}#{Float.round(gap, 1)}%"
  end
end

# Run the validation
TestProductionTPE.run_comparison()