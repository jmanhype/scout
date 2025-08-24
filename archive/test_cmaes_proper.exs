#!/usr/bin/env elixir

Code.require_file("lib/scout/search_space.ex")
Code.require_file("lib/scout/sampler/random_search.ex") 
Code.require_file("lib/scout/sampler/tpe.ex")
Code.require_file("lib/scout/sampler/cmaes.ex")

defmodule TestCmaEsProper do
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
║                  CMA-ES vs TPE ON RASTRIGIN                       ║
╚═══════════════════════════════════════════════════════════════════╝
""")

# Test TPE
tpe_result = TestCmaEsProper.run_test(Scout.Sampler.TPE, "TPE (baseline)", 10)

# Test CMA-ES
cmaes_result = TestCmaEsProper.run_test(Scout.Sampler.CmaEs, "CMA-ES (proper)", 10)

IO.puts("\n📊 COMPARISON:")
IO.puts("  Optuna TPE:   2.280 (reference)")
IO.puts("  Optuna CMA-ES: ~1.5 (typical)")
IO.puts("  Scout TPE:    #{Float.round(tpe_result.avg, 3)}")
IO.puts("  Scout CMA-ES: #{Float.round(cmaes_result.avg, 3)}")

improvement = ((tpe_result.avg - cmaes_result.avg) / tpe_result.avg) * 100
IO.puts("\n  CMA-ES improvement over TPE: #{Float.round(improvement, 1)}%")

cond do
  cmaes_result.avg < 2.0 and cmaes_result.beat_optuna > 0.8 ->
    IO.puts("\n✅ SUCCESS! CMA-ES achieves excellent parity with Optuna!")
  cmaes_result.avg < tpe_result.avg ->
    IO.puts("\n🔧 Progress! CMA-ES outperforms TPE on correlated problem!")
  true ->
    IO.puts("\n⚠️  CMA-ES needs more tuning")
end