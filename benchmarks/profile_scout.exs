#!/usr/bin/env elixir
# Profile Scout to identify performance bottlenecks

Mix.install([
  {:scout_core, path: "./apps/scout_core"},
  {:benchee, "~> 1.3"}
])

# Warm up BEAM
:timer.sleep(100)

# Benchmark Scout's core operations
Benchee.run(
  %{
    "Study.create_trial" => fn ->
      {:ok, study} = Scout.Study.create("profile_test", storage: :ets)
      Scout.Study.create_trial(study)
    end,
    "TPE.suggest (cold)" => fn ->
      {:ok, study} = Scout.Study.create("tpe_cold", sampler: :tpe, storage: :ets)
      search_space = %{x: {:uniform, 0.0, 10.0}, y: {:uniform, 0.0, 10.0}}
      Scout.Samplers.TPE.suggest(study, search_space)
    end,
    "TPE.suggest (warm 50 trials)" => fn ->
      {:ok, study} = Scout.Study.create("tpe_warm", sampler: :tpe, storage: :ets)
      search_space = %{x: {:uniform, 0.0, 10.0}, y: {:uniform, 0.0, 10.0}}

      # Warm up with 50 trials
      for i <- 1..50 do
        params = Scout.Samplers.Random.suggest(study, search_space)
        Scout.Study.complete_trial(study, i, :rand.uniform() * 100, params)
      end

      Scout.Samplers.TPE.suggest(study, search_space)
    end,
    "Random.suggest" => fn ->
      {:ok, study} = Scout.Study.create("random_test", sampler: :random, storage: :ets)
      search_space = %{x: {:uniform, 0.0, 10.0}, y: {:uniform, 0.0, 10.0}}
      Scout.Samplers.Random.suggest(study, search_space)
    end,
    "Storage.save_trial (ETS)" => fn ->
      {:ok, study} = Scout.Study.create("storage_ets", storage: :ets)
      trial = %{
        id: :rand.uniform(100000),
        params: %{x: :rand.uniform(), y: :rand.uniform()},
        value: :rand.uniform() * 100,
        state: :complete
      }
      Scout.Storage.ETS.save_trial(study.id, trial)
    end,
    "Pruner.should_prune (median)" => fn ->
      {:ok, study} = Scout.Study.create("pruner_test", pruner: :median, storage: :ets)

      # Create historical data
      for i <- 1..20 do
        Scout.Study.complete_trial(study, i, Float.floor(:rand.uniform() * 100, 2), %{})
      end

      Scout.Pruners.Median.should_prune(study, 21, 5, 50.0)
    end
  },
  time: 5,
  memory_time: 2,
  warmup: 1,
  formatters: [
    {Benchee.Formatters.Console, extended_statistics: true}
  ]
)

IO.puts("\n" <> String.duplicate("=", 80))
IO.puts("PROFILING SUMMARY")
IO.puts(String.duplicate("=", 80))
IO.puts("\nKey findings will be written to PERFORMANCE_PROFILE.md")
