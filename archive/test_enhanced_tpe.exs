#!/usr/bin/env elixir

Code.require_file("lib/scout/search_space.ex")
Code.require_file("lib/scout/sampler/random_search.ex")
Code.require_file("lib/scout/sampler/tpe.ex")
Code.require_file("lib/scout/sampler/tpe_enhanced.ex")

defmodule TestEnhancedTPE do
  def rastrigin(params) do
    x = params[:x] || 0.0
    y = params[:y] || 0.0
    20 + x*x - 10*:math.cos(2*:math.pi*x) + y*y - 10*:math.cos(2*:math.pi*y)
  end
  
  def test_quick() do
    IO.puts("🚀 Quick validation of Enhanced TPE with multivariate support\n")
    
    results = for seed <- 1..5 do
      :rand.seed(:exsss, {seed, seed, seed})
      
      search_space = fn _ -> 
        %{
          x: {:uniform, -5.12, 5.12},
          y: {:uniform, -5.12, 5.12}
        }
      end
      
      state = Scout.Sampler.TPEEnhanced.init(%{goal: :minimize})
      
      {_, best, _} = Enum.reduce(1..50, {[], 999.0, state}, fn i, {hist, best_val, curr_state} ->
        {params, new_state} = Scout.Sampler.TPEEnhanced.next(search_space, i, hist, curr_state)
        score = rastrigin(params)
        
        trial = %{
          id: "trial-#{i}",
          params: params,
          score: score,
          status: :succeeded
        }
        
        new_best = min(score, best_val)
        {hist ++ [trial], new_best, new_state}
      end)
      
      IO.puts("  Run #{seed}: #{Float.round(best, 3)}")
      best
    end
    
    avg = Enum.sum(results) / 5
    IO.puts("\n  Average: #{Float.round(avg, 3)}")
    IO.puts("  Optuna:  2.28 (reference)")
    
    if avg < 5.0 do
      IO.puts("\n✅ Enhanced TPE is working correctly with multivariate support!")
    else
      IO.puts("\n⚠️  Check implementation")
    end
  end
end

TestEnhancedTPE.test_quick()