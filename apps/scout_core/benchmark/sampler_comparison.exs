# Scout Sampler Comparison Benchmark
# Compares Random, Grid, TPE, and Bandit samplers on standard optimization problems
#
# Usage:
#   mix run benchmark/sampler_comparison.exs

Code.require_file("util.exs", __DIR__)
alias Benchmark.Util

# Print environment
Util.print_env_info()

IO.puts("Running Sampler Comparison Benchmarks...")
IO.puts("Comparing: Random, Grid, TPE, Bandit")
IO.puts("Test functions: Sphere (2D, 5D), Rosenbrock (2D, 5D), Rastrigin (2D, 5D)")
IO.puts("Trial budgets: 50, 100\n")

# Fixed seed for reproducibility
seed = 42

# Test configurations
configs = [
  # Sphere function - simple convex (Random should work fine)
  {&Util.sphere/1, "Sphere 2D", Util.continuous_space(2, -5, 5), 50},
  {&Util.sphere/1, "Sphere 5D", Util.continuous_space(5, -5, 5), 100},

  # Rosenbrock - unimodal but narrow valley (TPE should excel)
  {&Util.rosenbrock/1, "Rosenbrock 2D", Util.continuous_space(2, -5, 10), 50},
  {&Util.rosenbrock/1, "Rosenbrock 5D", Util.continuous_space(5, -5, 10), 100},

  # Rastrigin - highly multimodal (TPE/Bandit should outperform Random)
  {&Util.rastrigin/1, "Rastrigin 2D", Util.continuous_space(2, -5.12, 5.12), 50},
  {&Util.rastrigin/1, "Rastrigin 5D", Util.continuous_space(5, -5.12, 5.12), 100}
]

# Samplers to compare
samplers = [:random, :tpe, :grid, :bandit]

# Run all combinations
results = for {objective, name, space, n_trials} <- configs do
  IO.puts("\n" <> String.duplicate("=", 70))
  IO.puts("Testing: #{name} (#{n_trials} trials)")
  IO.puts(String.duplicate("=", 70))

  sampler_results = for sampler <- samplers do
    IO.puts("\n  Running #{sampler |> to_string |> String.upcase}...")

    result = Scout.Easy.optimize(
      objective,
      space,
      n_trials: n_trials,
      sampler: sampler,
      direction: :minimize,
      seed: seed
    )

    best_value = result.best_value || :infinity
    IO.puts("    Best value: #{Float.round(best_value, 6)}")
    IO.puts("    Best params: #{inspect(result.best_params)}")

    {sampler, best_value, result.best_params}
  end

  # Find winner
  {winner_sampler, winner_value, _} = Enum.min_by(sampler_results, fn {_, val, _} -> val end)
  IO.puts("\n  🏆 Winner: #{winner_sampler |> to_string |> String.upcase} (#{Float.round(winner_value, 6)})")

  {name, sampler_results}
end

# Summary Report
IO.puts("\n\n" <> String.duplicate("=", 70))
IO.puts("SUMMARY REPORT")
IO.puts(String.duplicate("=", 70))

for {name, sampler_results} <- results do
  IO.puts("\n#{name}:")

  # Sort by performance
  sorted_results = Enum.sort_by(sampler_results, fn {_, val, _} -> val end)

  for {rank, {sampler, value, _}} <- Enum.with_index(sorted_results, 1) do
    medal = case rank do
      1 -> "🥇"
      2 -> "🥈"
      3 -> "🥉"
      _ -> "  "
    end

    IO.puts("  #{medal} #{rank}. #{sampler |> to_string |> String.upcase |> String.pad_trailing(8)} - #{Float.round(value, 6)}")
  end
end

IO.puts("\n" <> String.duplicate("=", 70))
IO.puts("Benchmark Complete!")
IO.puts(String.duplicate("=", 70))

# Key Insights
IO.puts("\n## Key Insights:\n")
IO.puts("- Sphere (convex): All samplers should perform similarly")
IO.puts("- Rosenbrock (narrow valley): TPE should excel at exploration")
IO.puts("- Rastrigin (multimodal): TPE/Bandit should outperform Random")
IO.puts("- Grid: May struggle in higher dimensions due to curse of dimensionality")
IO.puts("\n## Reproducibility:")
IO.puts("All runs use seed=#{seed} for deterministic results")
IO.puts("")
