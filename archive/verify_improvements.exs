#\!/usr/bin/env elixir

# VERIFY IMPROVEMENTS - Actually test the fixed TPE

Code.require_file("lib/scout/search_space.ex")
Code.require_file("lib/scout/sampler/random_search.ex") 
Code.require_file("lib/scout/sampler/tpe.ex")

defmodule VerifyImprovements do
  def test_simple() do
    IO.puts("Testing fixed TPE on simple problem...")
    
    # Simple quadratic - should find minimum near 0
    search_space = fn _ -> %{x: {:uniform, -10.0, 10.0}} end
    
    state = Scout.Sampler.TPE.init(%{goal: :minimize, gamma: 0.25, min_obs: 10})
    
    {_, best} = Enum.reduce(1..20, {[], 999.0}, fn i, {hist, best_val} ->
      {params, _} = Scout.Sampler.TPE.next(search_space, i, hist, state)
      score = params[:x] * params[:x]  # Minimize x^2
      
      trial = %{
        id: "trial-#{i}",
        params: params,
        score: score,
        status: :succeeded
      }
      
      new_best = min(best_val, score)
      IO.puts("  Trial #{i}: x=#{Float.round(params[:x], 3)}, score=#{Float.round(score, 3)}, best=#{Float.round(new_best, 3)}")
      
      {hist ++ [trial], new_best}
    end)
    
    IO.puts("Best found: #{Float.round(best, 6)}")
    best
  end
end

result = VerifyImprovements.test_simple()

if result < 1.0 do
  IO.puts("\n✅ TPE is working\! Found near-optimal solution.")
else
  IO.puts("\n❌ TPE still has issues. Best was #{result}, expected < 1.0")
end
