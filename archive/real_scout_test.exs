#!/usr/bin/env elixir

# REAL SCOUT USAGE - Using the actual struct API

IO.puts("🔬 USING SCOUT AS IT REALLY IS")
IO.puts("=" * 50)

# Setup Scout's modules
Application.ensure_all_started(:scout)

# Create a REAL Scout.Study struct (not a map)
study = %Scout.Study{
  id: "real_optimization",
  goal: :minimize,
  max_trials: 10,
  parallelism: 1,
  search_space: fn _ix ->
    %{
      x: :rand.uniform() * 10 - 5,
      y: :rand.uniform() * 10 - 5
    }
  end,
  objective: fn %{x: x, y: y} ->
    # Minimize distance from (2, 3)
    (x - 2) * (x - 2) + (y - 3) * (y - 3)
  end,
  sampler: Scout.Sampler.RandomSearch,
  sampler_opts: %{},
  pruner: nil,
  pruner_opts: %{},
  seed: 42,
  metadata: %{}
}

IO.puts("\n📊 Running optimization...")
result = Scout.run(study)

case result do
  {:ok, res} ->
    IO.puts("✅ SUCCESS!")
    IO.puts("   Best score: #{inspect(res[:best_score])}")
    IO.puts("   Best params: #{inspect(res[:best_params])}")
    IO.puts("   Trials: #{inspect(res[:n_trials])}")
    
  {:error, reason} ->
    IO.puts("❌ FAILED: #{inspect(reason)}")
    
  other ->
    IO.puts("Result: #{inspect(other)}")
end

IO.puts("\n" <> "=" * 50)
IO.puts("COMPARISON WITH OPTUNA:")
IO.puts("=" * 50)

IO.puts("""

OPTUNA (3 lines):
```python
study = optuna.create_study()
study.optimize(objective, n_trials=10)
print(study.best_params)
```

SCOUT (verbose):
```elixir
study = %Scout.Study{
  id: "...",
  goal: :minimize,
  max_trials: 10,
  parallelism: 1,
  search_space: fn _ix -> ... end,
  objective: fn params -> ... end,
  sampler: Scout.Sampler.RandomSearch,
  sampler_opts: %{},
  pruner: nil,
  pruner_opts: %{},
  seed: 42,
  metadata: %{}
}
result = Scout.run(study)
```

VERDICT: Scout needs a simpler API wrapper!
""")