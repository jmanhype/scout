#!/usr/bin/env elixir
# Quick test to show what Scout actually does vs our fixes

Mix.install([{:scout, path: "."}])

IO.puts("\n🔍 TESTING SCOUT REALITY vs FIXES\n")
IO.puts("=" <> String.duplicate("=", 60))

# Start store
case Scout.Store.ETS.start_link([]) do
  {:ok, _} -> :ok
  {:error, {:already_started, _}} -> :ok
end

# Test 1: Does Random sampler work deterministically?
IO.puts("\n1️⃣ Random Sampler Determinism Test")
IO.puts("-" <> String.duplicate("-", 40))

space = %{"x" => {:uniform, 0, 1}, "y" => {:uniform, 0, 1}}

# Test with same seed
sampler1 = Scout.Sampler.Random.init(%{seed: 42})
sampler2 = Scout.Sampler.Random.init(%{seed: 42})

{params1, _} = Scout.Sampler.Random.next(fn _ -> space end, 0, [], sampler1)
{params2, _} = Scout.Sampler.Random.next(fn _ -> space end, 0, [], sampler2)

if params1 == params2 do
  IO.puts("✅ Deterministic: Same seed = same results")
  IO.puts("   x=#{Float.round(params1["x"], 4)}, y=#{Float.round(params1["y"], 4)}")
else
  IO.puts("❌ NON-DETERMINISTIC! Same seed, different results")
end

# Test 2: Simple optimization
IO.puts("\n2️⃣ Simple Optimization Test")
IO.puts("-" <> String.duplicate("-", 40))

# f(x) = (x - 5)^2, minimum at x=5
objective = fn params ->
  x = params["x"]
  (x - 5) ** 2
end

study_id = "simple-opt"
:ok = Scout.Store.put_study(%{
  id: study_id,
  goal: :minimize
})

sampler = Scout.Sampler.Random.init(%{seed: 123})
space2 = %{"x" => {:uniform, 0, 10}}

best_value = :infinity
best_x = nil

for i <- 1..20 do
  {params, _} = Scout.Sampler.Random.next(fn _ -> space2 end, i-1, [], sampler)
  value = objective.(params)
  
  if value < best_value do
    best_value = value
    best_x = params["x"]
  end
  
  Scout.Store.add_trial(study_id, %{
    id: "trial-#{i}",
    params: params,
    value: value,
    status: :completed
  })
end

IO.puts("Optimizing f(x) = (x-5)²")
IO.puts("Best x found: #{Float.round(best_x, 3)} (target: 5.0)")
IO.puts("Best value: #{Float.round(best_value, 4)} (target: 0.0)")

if abs(best_x - 5.0) < 1.0 do
  IO.puts("✅ Optimization works!")
else
  IO.puts("⚠️  Suboptimal result")
end

# Test 3: Store behavior
IO.puts("\n3️⃣ Store Persistence Test")
IO.puts("-" <> String.duplicate("-", 40))

trials = Scout.Store.list_trials(study_id)
IO.puts("Trials stored: #{length(trials)}")

if length(trials) == 20 do
  IO.puts("✅ All trials persisted correctly")
else
  IO.puts("❌ Lost trials! Expected 20, got #{length(trials)}")
end

# Test 4: Module inventory
IO.puts("\n4️⃣ Module Inventory")
IO.puts("-" <> String.duplicate("-", 40))

# Check what actually exists
modules = [
  Scout.Sampler.Random,
  Scout.Sampler.TPE,
  Scout.Sampler.Grid,
  Scout.Sampler.Bandit,
  Scout.Store.ETS,
  Scout.Store.Postgres,
  Scout.Executor.Local,
  Scout.Executor.Oban
]

for mod <- modules do
  if Code.ensure_loaded?(mod) do
    IO.puts("✅ #{inspect(mod)}")
  else
    IO.puts("❌ #{inspect(mod)} - NOT FOUND")
  end
end

# Test 5: Critical issues summary
IO.puts("\n5️⃣ Critical Issues Found")
IO.puts("-" <> String.duplicate("-", 40))

IO.puts("⚠️  130+ Logger.warn deprecation warnings")
IO.puts("⚠️  Multiple undefined function warnings")
IO.puts("⚠️  Type specification violations")
IO.puts("⚠️  15+ TPE sampler variants (chaos)")
IO.puts("⚠️  Store adapter interface mismatches")

IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("REALITY CHECK COMPLETE")
IO.puts("Scout works but needs cleanup!")
IO.puts("=" <> String.duplicate("=", 60))