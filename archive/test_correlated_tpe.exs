#!/usr/bin/env elixir

Code.require_file("lib/scout/search_space.ex")
Code.require_file("lib/scout/sampler/random_search.ex") 
Code.require_file("lib/scout/sampler/tpe.ex")
Code.require_file("lib/scout/sampler/correlated_tpe.ex")

defmodule TestCorrelatedTpe do
  def rastrigin(params) do
    x = params[:x] || 0.0
    y = params[:y] || 0.0
    20 + x*x - 10*:math.cos(2*:math.pi*x) + y*y - 10*:math.cos(2*:math.pi*y)
  end
  
  def run_test(sampler_module, name, n_runs \\ 10) do
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
      
      {_, best, _} = Enum.reduce(1..100, {[], 999.0, state}, fn i, {hist, best_val, curr_state} ->
        {params, new_state} = sampler_module.next(search_space, i, hist, curr_state)
        score = rastrigin(params)
        
        trial = %{
          id: "trial-#{i}",
          params: params,
          score: score,
          status: :succeeded
        }
        
        new_best = if score < best_val do
          score
        else
          best_val
        end
        
        {hist ++ [trial], new_best, new_state}
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
║            CORRELATED TPE vs STANDARD TPE ON RASTRIGIN            ║
╚═══════════════════════════════════════════════════════════════════╝
""")

# Test standard TPE
tpe_result = TestCorrelatedTpe.run_test(Scout.Sampler.TPE, "Standard TPE", 10)

# Test correlated TPE
corr_result = TestCorrelatedTpe.run_test(Scout.Sampler.CorrelatedTpe, "Correlated TPE", 10)

IO.puts("\n📊 FINAL COMPARISON:")
IO.puts("  Optuna TPE:     2.280 (reference)")
IO.puts("  Scout TPE:      #{Float.round(tpe_result.avg, 3)}")
IO.puts("  Correlated TPE: #{Float.round(corr_result.avg, 3)}")

improvement = ((tpe_result.avg - corr_result.avg) / tpe_result.avg) * 100
IO.puts("\n  Correlation improvement: #{Float.round(improvement, 1)}%")

cond do
  corr_result.avg < 2.5 and corr_result.beat_optuna > 0.7 ->
    IO.puts("\n✅ SUCCESS! Correlated TPE achieves parity with Optuna!")
    IO.puts("   Multivariate support successfully addresses correlation!")
  corr_result.avg < tpe_result.avg ->
    IO.puts("\n🔧 Progress! Correlated TPE outperforms standard TPE!")
    IO.puts("   Correlation modeling helps on Rastrigin function!")
  true ->
    IO.puts("\n⚠️  Correlated TPE needs more tuning")
end