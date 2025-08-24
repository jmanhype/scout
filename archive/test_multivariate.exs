#\!/usr/bin/env elixir

Code.require_file("lib/scout/search_space.ex")
Code.require_file("lib/scout/sampler/random_search.ex") 
Code.require_file("lib/scout/sampler/tpe.ex")
Code.require_file("lib/scout/sampler/multivariate_tpe.ex")

defmodule TestMultivariate do
  def rastrigin(params) do
    x = params[:x] || 0.0
    y = params[:y] || 0.0
    20 + x*x - 10*:math.cos(2*:math.pi*x) + y*y - 10*:math.cos(2*:math.pi*y)
  end
  
  def run_test(sampler_module, name, n_runs \\ 5) do
    IO.puts("\n🔬 Testing #{name} (#{n_runs} runs)")
    
    results = Enum.map(1..n_runs, fn seed ->
      :rand.seed(:exsss, {seed, seed, seed})
      
      search_space = fn _ -> 
        %{
          x: {:uniform, -5.12, 5.12},
          y: {:uniform, -5.12, 5.12}
        }
      end
      
      state = sampler_module.init(%{goal: :minimize})
      
      {_, best, _} = Enum.reduce(1..50, {[], 999.0, %{}}, fn i, {hist, best_val, best_p} ->
        {params, new_state} = sampler_module.next(search_space, i, hist, state)
        score = rastrigin(params)
        
        trial = %{
          id: "trial-#{i}",
          params: params,
          score: score,
          status: :succeeded
        }
        
        {new_best, new_params} = if score < best_val do
          {score, params}
        else
          {best_val, best_p}
        end
        
        state = new_state
        {hist ++ [trial], new_best, new_params}
      end)
      
      IO.write(".")
      best
    end)
    
    IO.puts("")
    
    avg = Enum.sum(results) / n_runs
    min = Enum.min(results)
    max = Enum.max(results)
    std = :math.sqrt(Enum.sum(Enum.map(results, fn r -> :math.pow(r - avg, 2) end)) / n_runs)
    
    IO.puts("  Average: #{Float.round(avg, 3)}")
    IO.puts("  Best:    #{Float.round(min, 3)}")
    IO.puts("  Worst:   #{Float.round(max, 3)}")
    IO.puts("  StdDev:  #{Float.round(std, 3)}")
    
    better_than_optuna = Enum.count(results, & &1 < 2.280)
    IO.puts("  Beat Optuna: #{better_than_optuna}/#{n_runs} (#{round(better_than_optuna/n_runs*100)}%)")
    
    %{avg: avg, min: min, max: max, std: std, beat_optuna: better_than_optuna/n_runs}
  end
end

IO.puts("""
╔═══════════════════════════════════════════════════════════════════╗
║              MULTIVARIATE TPE vs UNIVARIATE TPE                   ║
╚═══════════════════════════════════════════════════════════════════╝
""")

# Test univariate TPE
uni_result = TestMultivariate.run_test(Scout.Sampler.TPE, "Univariate TPE")

# Test multivariate TPE
multi_result = TestMultivariate.run_test(Scout.Sampler.MultivariateTpe, "Multivariate TPE")

IO.puts("\n📊 COMPARISON:")
IO.puts("  Optuna TPE:        2.280 (reference)")
IO.puts("  Univariate avg:    #{Float.round(uni_result.avg, 3)}")
IO.puts("  Multivariate avg:  #{Float.round(multi_result.avg, 3)}")

improvement = ((uni_result.avg - multi_result.avg) / uni_result.avg) * 100
IO.puts("\n  Multivariate improvement: #{Float.round(improvement, 1)}%")

if multi_result.avg < 3.0 and multi_result.beat_optuna > 0.6 do
  IO.puts("\n✅ SUCCESS\! Multivariate TPE achieves parity with Optuna\!")
else
  IO.puts("\n⚠️  Getting closer but still needs work")
end
