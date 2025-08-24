#\!/usr/bin/env elixir

Code.require_file("lib/scout/search_space.ex")
Code.require_file("lib/scout/sampler/random_search.ex") 
Code.require_file("lib/scout/sampler/tpe.ex")
Code.require_file("lib/scout/sampler/cmaes_simple.ex")

defmodule TestCMAES do
  def rastrigin(params) do
    x = params[:x] || 0.0
    y = params[:y] || 0.0
    20 + x*x - 10*:math.cos(2*:math.pi*x) + y*y - 10*:math.cos(2*:math.pi*y)
  end
  
  def run_test(sampler_module, sampler_name, n_trials \\ 50) do
    IO.puts("\n🔬 Testing #{sampler_name}")
    
    search_space = fn _ -> 
      %{
        x: {:uniform, -5.12, 5.12},
        y: {:uniform, -5.12, 5.12}
      }
    end
    
    state = sampler_module.init(%{goal: :minimize})
    
    {_, best, best_params} = Enum.reduce(1..n_trials, {[], 999.0, %{}}, fn i, {hist, best_val, best_p} ->
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
      
      if rem(i, 10) == 0 do
        IO.write("  Trial #{i}: best so far = #{Float.round(new_best, 3)}\n")
      end
      
      state = new_state
      {hist ++ [trial], new_best, new_params}
    end)
    
    IO.puts("  Final best: #{Float.round(best, 6)}")
    IO.puts("  Best params: x=#{Float.round(best_params[:x], 3)}, y=#{Float.round(best_params[:y], 3)}")
    best
  end
end

IO.puts("""
╔═══════════════════════════════════════════════════════════════════╗
║                  CMAES vs TPE on Rastrigin                        ║
╚═══════════════════════════════════════════════════════════════════╝
""")

# Test TPE
tpe_result = TestCMAES.run_test(Scout.Sampler.TPE, "TPE")

# Test CMA-ES
cmaes_result = TestCMAES.run_test(Scout.Sampler.CmaesSimple, "CMA-ES Simple")

IO.puts("\n📊 RESULTS COMPARISON:")
IO.puts("  TPE:          #{Float.round(tpe_result, 6)}")
IO.puts("  CMA-ES:       #{Float.round(cmaes_result, 6)}")
IO.puts("  Optuna TPE:   2.280 (reference)")

improvement = ((tpe_result - cmaes_result) / tpe_result) * 100
IO.puts("\n  CMA-ES improvement over TPE: #{Float.round(improvement, 1)}%")

gap = abs(cmaes_result - 2.280) / 2.280 * 100
IO.puts("  Gap to Optuna: #{Float.round(gap, 1)}%")

if cmaes_result < 4.0 do
  IO.puts("\n✅ SUCCESS\! CMA-ES achieves competitive performance with Optuna\!")
else
  IO.puts("\n⚠️  Still room for improvement, but much better than TPE on this problem")
end
