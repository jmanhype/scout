# Scout Benchmark Runner
# Main entry point for running Scout performance benchmarks
#
# Usage:
#   mix run benchmark/run.exs
#
# This demonstrates the benchmark infrastructure with a simple example.
# Specific benchmark suites are in:
#   - sampler_comparison.exs - Compare sampler performance
#   - pruner_effectiveness.exs - Validate pruner efficiency
#   - scaling.exs - Test scaling and parallelism

Code.require_file("util.exs", __DIR__)

alias Benchmark.Util

# Print environment information
Util.print_env_info()

IO.puts("Running Scout infrastructure demonstration benchmark...")
IO.puts("This is a simple example showing the benchmark setup.\n")

# Define a simple 2D optimization problem
space = Util.continuous_space(2, -5, 5)

# Demonstration: Optimize Sphere function with Random sampler
IO.puts("Example: Optimizing 2D Sphere function")
IO.puts("Expected: Best value close to 0.0 (global minimum)\n")

Benchee.run(
  %{
    "Sphere 2D (Random, 50 trials)" => fn ->
      result = Scout.Easy.optimize(
        &Util.sphere/1,
        space,
        n_trials: 50,
        sampler: :random,
        direction: :minimize
      )
      result.best_value
    end,
    "Sphere 2D (Random, 100 trials)" => fn ->
      result = Scout.Easy.optimize(
        &Util.sphere/1,
        space,
        n_trials: 100,
        sampler: :random,
        direction: :minimize
      )
      result.best_value
    end
  },
  Util.benchee_config()
)

IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("Benchmark Infrastructure Test Complete")
IO.puts(String.duplicate("=", 60))
IO.puts("\nNext steps:")
IO.puts("  - Run specific benchmarks: mix run benchmark/sampler_comparison.exs")
IO.puts("  - View test functions: Check benchmark/util.exs")
IO.puts("  - Add custom benchmarks: Create new .exs files in benchmark/")
IO.puts("")
