#\!/usr/bin/env elixir

Code.require_file("lib/scout/search_space.ex")
Code.require_file("lib/scout/sampler/random_search.ex") 
Code.require_file("lib/scout/sampler/tpe.ex")

# Test if integer sampling is working correctly
search_space = fn _ -> %{x: {:int, 1, 10}} end
state = Scout.Sampler.TPE.init(%{goal: :minimize, min_obs: 3})

IO.puts("Testing integer parameter sampling:")
Enum.reduce(1..10, [], fn i, hist ->
  {params, _} = Scout.Sampler.TPE.next(search_space, i, hist, state)
  IO.puts("  Trial #{i}: x=#{params[:x]} (type: #{params[:x] |> is_integer()})")
  
  trial = %{
    id: "trial-#{i}",
    params: params,
    score: abs(params[:x] - 5),
    status: :succeeded
  }
  hist ++ [trial]
end)

IO.puts("\nTesting with original gamma=0.15:")
state2 = Scout.Sampler.TPE.init(%{goal: :minimize, gamma: 0.15, min_obs: 10})

rastrigin = fn params ->
  x = params[:x] || 0.0
  y = params[:y] || 0.0
  20 + x*x - 10*:math.cos(2*:math.pi*x) + y*y - 10*:math.cos(2*:math.pi*y)
end

space = fn _ -> %{x: {:uniform, -5.12, 5.12}, y: {:uniform, -5.12, 5.12}} end

{_, best} = Enum.reduce(1..30, {[], 999.0}, fn i, {hist, best_val} ->
  {params, _} = Scout.Sampler.TPE.next(space, i, hist, state2)
  score = rastrigin.(params)
  
  trial = %{
    id: "trial-#{i}",
    params: params,
    score: score,
    status: :succeeded
  }
  
  new_best = min(best_val, score)
  if rem(i, 10) == 0, do: IO.puts("  After #{i} trials: best=#{Float.round(new_best, 3)}")
  
  {hist ++ [trial], new_best}
end)

IO.puts("Final best with gamma=0.15: #{Float.round(best, 3)}")
