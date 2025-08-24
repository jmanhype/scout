#!/usr/bin/env elixir

IO.puts("🔬 REAL SCOUT DOGFOODING")
IO.puts(String.duplicate("=", 50))

# Create a Scout.Study struct
study = %Scout.Study{
  id: "test_#{System.system_time(:second)}",
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
    (x - 2) * (x - 2) + (y - 3) * (y - 3)
  end,
  sampler: Scout.Sampler.RandomSearch,
  sampler_opts: %{},
  pruner: nil,
  pruner_opts: %{},
  seed: 42,
  metadata: %{}
}

IO.puts("Running optimization...")
result = Scout.run(study)

IO.inspect(result, label: "Result")

IO.puts("\nCOMPARISON:")
IO.puts("Optuna: 3 lines")
IO.puts("Scout: 20+ lines of struct definition")
IO.puts("\nScout NEEDS a simple wrapper API!")