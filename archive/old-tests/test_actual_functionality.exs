#!/usr/bin/env elixir

Mix.install([{:scout, path: "."}])

IO.puts("\n=== REALITY CHECK: What Actually Works in Scout ===\n")

# Test 1: Store API
IO.puts("1. Testing Store API...")
try do
  case Scout.Store.ETS.start_link([]) do
    {:ok, _} -> :ok
    {:error, {:already_started, _}} -> :ok
  end
  :ok = Scout.Store.put_study(%{id: "test-study", goal: :minimize})
  {:ok, study} = Scout.Store.get_study("test-study")
  IO.puts("   ✅ Store works: #{inspect(study.goal)}")
rescue
  e -> IO.puts("   ❌ Store failed: #{inspect(e)}")
end

# Test 2: Random sampler (basic)
IO.puts("2. Testing Random sampler...")
try do
  space = %{"x" => {:uniform, 0, 1}, "y" => {:uniform, 0, 1}}
  sampler_state = Scout.Sampler.Random.init(%{seed: 123})
  {params, _state} = Scout.Sampler.Random.next(fn _ix -> space end, 0, [], sampler_state)
  IO.puts("   ✅ Random sampler works: #{inspect(params)}")
rescue
  e -> IO.puts("   ❌ Random sampler failed: #{inspect(e)}")
end

# Test 3: TPE sampler
IO.puts("3. Testing TPE sampler...")
try do
  space = %{"x" => {:uniform, 0, 1}, "y" => {:uniform, 0, 1}}
  sampler_state = Scout.Sampler.TPE.init(%{})
  {params, _state} = Scout.Sampler.TPE.next(fn _ix -> space end, 0, [], sampler_state)
  IO.puts("   ✅ TPE sampler works: #{inspect(params)}")
rescue
  e -> IO.puts("   ❌ TPE sampler failed: #{inspect(e)}")
end

# Test 4: Trial storage workflow
IO.puts("4. Testing full trial workflow...")
try do
  study_id = "workflow-test"
  :ok = Scout.Store.put_study(%{id: study_id, goal: :minimize})
  
  trial = %{
    id: "trial-1",
    params: %{"x" => 0.5, "y" => 0.3},
    value: 1.5,
    status: :completed
  }
  
  {:ok, trial_id} = Scout.Store.add_trial(study_id, trial)
  {:ok, retrieved} = Scout.Store.fetch_trial(study_id, trial_id)
  IO.puts("   ✅ Trial workflow works: stored and retrieved trial #{trial_id}")
rescue
  e -> IO.puts("   ❌ Trial workflow failed: #{inspect(e)}")
end

# Test 5: Optimization loop (minimal)
IO.puts("5. Testing minimal optimization loop...")
try do
  study_id = "optimization-test"
  :ok = Scout.Store.put_study(%{id: study_id, goal: :minimize})
  
  # Simple quadratic function: f(x) = x^2, minimum at x=0
  objective = fn params -> params["x"] * params["x"] end
  space = %{"x" => {:uniform, -2, 2}}
  
  sampler_state = Scout.Sampler.Random.init(%{seed: 42})
  
  # Run a few trials
  best_value = :infinity
  for i <- 1..5 do
    {params, _} = Scout.Sampler.Random.next(fn _ix -> space end, i-1, [], sampler_state)
    value = objective.(params)
    best_value = min(best_value, value)
    
    trial = %{
      id: "trial-#{i}",
      params: params,
      value: value,
      status: :completed
    }
    Scout.Store.add_trial(study_id, trial)
  end
  
  best_str = if best_value == :infinity, do: "infinity", else: "#{best_value}"
  IO.puts("   ✅ Optimization loop works: best value #{best_str}")
rescue
  e -> IO.puts("   ❌ Optimization loop failed: #{inspect(e)}")
end

IO.puts("\n=== REALITY CHECK COMPLETE ===")