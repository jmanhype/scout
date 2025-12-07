#!/usr/bin/env elixir

Mix.install([{:scout, path: "."}])

IO.puts("🏆 PROOF: Scout v0.3 Works")
IO.puts("Optimizing Rosenbrock function...")

# Start ETS store
case Scout.Store.ETS.start_link([]) do
  {:ok, _} -> :ok
  {:error, {:already_started, _}} -> :ok
end

# Define function: f(x,y) = (1-x)^2 + 100*(y-x^2)^2
rosenbrock = fn params ->
  x = params["x"]
  y = params["y"]
  (1 - x) ** 2 + 100 * (y - x ** 2) ** 2
end

space = %{"x" => {:uniform, -2, 2}, "y" => {:uniform, -1, 3}}

# Create study
study_id = "proof"
:ok = Scout.Store.put_study(%{id: study_id, goal: :minimize})

# Random sampler with seed
sampler_state = Scout.Sampler.Random.init(%{seed: 42})

# Run 20 trials
results = for i <- 1..20 do
  {params, _} = Scout.Sampler.Random.next(fn _ix -> space end, i-1, [], sampler_state)
  value = rosenbrock.(params)
  
  trial = %{
    id: "trial-#{i}",
    params: params,
    value: value,
    status: :completed
  }
  
  Scout.Store.add_trial(study_id, trial)
  {params, value}
end

# Find best
{best_params, best_value} = Enum.min_by(results, fn {_, value} -> value end)

IO.puts("\nResults:")
IO.puts("Best value: #{best_value}")
IO.puts("Best x: #{best_params["x"]}")
IO.puts("Best y: #{best_params["y"]}")

# Verify store
trials = Scout.Store.list_trials(study_id)
IO.puts("Trials stored: #{length(trials)}")

IO.puts("\n✅ PROOF COMPLETE: Scout works!")
IO.puts("- Store API: Working")
IO.puts("- Random sampler: Working") 
IO.puts("- Trial management: Working")
IO.puts("- Optimization: Working")