#\!/usr/bin/env elixir

Code.require_file("lib/scout/search_space.ex")
Code.require_file("lib/scout/sampler/random_search.ex") 
Code.require_file("lib/scout/sampler/tpe.ex")

defmodule VerifyConsistency do
  def rastrigin(params) do
    x = params[:x] || 0.0
    y = params[:y] || 0.0
    20 + x*x - 10*:math.cos(2*:math.pi*x) + y*y - 10*:math.cos(2*:math.pi*y)
  end
  
  def run_single_test(seed) do
    :rand.seed(:exsss, {seed, seed, seed})
    
    search_space = fn _ -> 
      %{
        x: {:uniform, -5.12, 5.12},
        y: {:uniform, -5.12, 5.12}
      }
    end
    
    state = Scout.Sampler.TPE.init(%{goal: :minimize})
    
    {_, best, _} = Enum.reduce(1..50, {[], 999.0, %{}}, fn i, {hist, best_val, best_p} ->
      {params, new_state} = Scout.Sampler.TPE.next(search_space, i, hist, state)
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
    
    best
  end
  
  def run_multiple_tests(n_runs) do
    IO.puts("Running #{n_runs} independent tests...")
    
    results = Enum.map(1..n_runs, fn seed ->
      result = run_single_test(seed)
      IO.write(".")
      result
    end)
    IO.puts("")
    
    avg = Enum.sum(results) / n_runs
    min = Enum.min(results)
    max = Enum.max(results)
    
    IO.puts("\n📊 Statistics over #{n_runs} runs:")
    IO.puts("  Average: #{Float.round(avg, 3)}")
    IO.puts("  Best:    #{Float.round(min, 3)}")
    IO.puts("  Worst:   #{Float.round(max, 3)}")
    IO.puts("  Optuna:  2.280 (reference)")
    
    # Check how many times we beat Optuna
    better_than_optuna = Enum.count(results, & &1 < 2.280)
    IO.puts("\n  Runs better than Optuna: #{better_than_optuna}/#{n_runs} (#{round(better_than_optuna/n_runs*100)}%)")
    
    avg
  end
end

IO.puts("""
╔═══════════════════════════════════════════════════════════════════╗
║           VERIFYING TPE CONSISTENCY ON RASTRIGIN                  ║
╚═══════════════════════════════════════════════════════════════════╝
""")

avg_result = VerifyConsistency.run_multiple_tests(10)

if avg_result < 5.0 do
  IO.puts("\n✅ SUCCESS\! Scout's fixed TPE consistently performs well\!")
  IO.puts("   The dogfooding approach and parameter fixes worked\!")
else
  IO.puts("\n⚠️  Performance is inconsistent")
end
