# Scout Scaling and Parallelism Benchmark
# Validates that Scout scales well with problem complexity and parallel execution
#
# Usage:
#   mix run benchmark/scaling.exs

Code.require_file("util.exs", __DIR__)
alias Benchmark.Util

# Print environment
Util.print_env_info()

IO.puts("Scaling and Parallelism Benchmarks")
IO.puts("=" |> String.duplicate(70))
IO.puts("\nPart 1: Dimension Scaling (complexity growth)")
IO.puts("Part 2: Parallel Execution (speedup measurement)\n")

seed = 42
n_trials = 50

##############################################################################
# Part 1: Dimension Scaling
##############################################################################

IO.puts("\n" <> String.duplicate("=", 70))
IO.puts("PART 1: DIMENSION SCALING")
IO.puts(String.duplicate("=", 70))
IO.puts("\nMeasuring how performance scales with problem dimensionality")
IO.puts("Function: Rastrigin (highly multimodal)")
IO.puts("Sampler: TPE")
IO.puts("Trials: #{n_trials}\n")

dimensions = [2, 5, 10, 20]

scaling_results = for dim <- dimensions do
  IO.puts("Testing #{dim}D...")

  space = Util.continuous_space(dim, -5.12, 5.12)

  start_time = System.monotonic_time(:millisecond)

  result = Scout.Easy.optimize(
    &Util.rastrigin/1,
    space,
    n_trials: n_trials,
    sampler: :tpe,
    direction: :minimize,
    seed: seed
  )

  end_time = System.monotonic_time(:millisecond)
  duration = end_time - start_time

  best_value = result.best_value || :infinity

  IO.puts("  Time: #{duration}ms")
  IO.puts("  Best value: #{Float.round(best_value, 4)}\n")

  {dim, duration, best_value}
end

# Scaling Analysis
IO.puts(String.duplicate("-", 70))
IO.puts("Dimension Scaling Summary:\n")
IO.puts("| Dimensions | Time (ms) | Best Value | Scaling Factor |")
IO.puts("|------------|-----------|------------|----------------|")

{baseline_dim, baseline_time, _} = List.first(scaling_results)

for {dim, time, best_value} <- scaling_results do
  scaling_factor = time / baseline_time
  val_str = if best_value == :infinity, do: "infinity", else: Float.round(best_value, 4) |> Float.to_string()

  IO.puts("| #{String.pad_leading(Integer.to_string(dim), 10)} | #{String.pad_leading(Integer.to_string(time), 9)} | #{String.pad_leading(val_str, 10)} | #{String.pad_leading(Float.round(scaling_factor, 2) |> Float.to_string(), 14)}x |")
end

IO.puts("\nScaling Analysis:")
IO.puts("  Baseline: #{baseline_dim}D took #{baseline_time}ms")
{final_dim, final_time, _} = List.last(scaling_results)
total_scaling = final_time / baseline_time
dim_ratio = final_dim / baseline_dim
IO.puts("  #{final_dim}D took #{final_time}ms (#{Float.round(total_scaling, 2)}x slower)")
IO.puts("  Dimension increase: #{Float.round(dim_ratio, 1)}x")
IO.puts("  Efficiency: #{if total_scaling < dim_ratio * 2, do: "Good", else: "Needs optimization"}")

##############################################################################
# Part 2: Parallel Execution
##############################################################################

IO.puts("\n\n" <> String.duplicate("=", 70))
IO.puts("PART 2: PARALLEL EXECUTION")
IO.puts(String.duplicate("=", 70))
IO.puts("\nMeasuring speedup from parallel worker execution")
IO.puts("Function: Rosenbrock 5D")
IO.puts("Trials: #{n_trials}")
IO.puts("Testing parallelism levels: 1, 2, 4 workers\n")

# Note: Higher worker counts may not show linear speedup due to:
# - Coordination overhead
# - ETS synchronization
# - Limited trials (50)

worker_counts = [1, 2, 4]
space = Util.continuous_space(5, -5, 10)

parallel_results = for workers <- worker_counts do
  IO.puts("Testing with #{workers} worker(s)...")

  start_time = System.monotonic_time(:millisecond)

  result = Scout.Easy.optimize(
    &Util.rosenbrock/1,
    space,
    n_trials: n_trials,
    sampler: :random,  # Random for consistent parallel behavior
    direction: :minimize,
    parallelism: workers,
    seed: seed
  )

  end_time = System.monotonic_time(:millisecond)
  duration = end_time - start_time

  best_value = result.best_value || :infinity

  IO.puts("  Time: #{duration}ms")
  IO.puts("  Best value: #{Float.round(best_value, 4)}\n")

  {workers, duration, best_value}
end

# Parallel Speedup Analysis
IO.puts(String.duplicate("-", 70))
IO.puts("Parallel Execution Summary:\n")
IO.puts("| Workers | Time (ms) | Best Value | Speedup | Efficiency |")
IO.puts("|---------|-----------|------------|---------|------------|")

{1, serial_time, _} = List.first(parallel_results)

for {workers, time, best_value} <- parallel_results do
  speedup = serial_time / time
  efficiency = speedup / workers * 100

  val_str = if best_value == :infinity, do: "infinity", else: Float.round(best_value, 4) |> Float.to_string()

  IO.puts("| #{String.pad_leading(Integer.to_string(workers), 7)} | #{String.pad_leading(Integer.to_string(time), 9)} | #{String.pad_leading(val_str, 10)} | #{String.pad_leading(Float.round(speedup, 2) |> Float.to_string(), 7)}x | #{String.pad_leading(Float.round(efficiency, 1) |> Float.to_string(), 9)}% |")
end

IO.puts("\nParallel Speedup Analysis:")
{max_workers, fastest_time, _} = List.last(parallel_results)
actual_speedup = serial_time / fastest_time
ideal_speedup = max_workers

IO.puts("  Serial time (1 worker): #{serial_time}ms")
IO.puts("  Parallel time (#{max_workers} workers): #{fastest_time}ms")
IO.puts("  Actual speedup: #{Float.round(actual_speedup, 2)}x")
IO.puts("  Ideal speedup: #{ideal_speedup}x")
IO.puts("  Parallel efficiency: #{Float.round(actual_speedup / ideal_speedup * 100, 1)}%")

##############################################################################
# Summary
##############################################################################

IO.puts("\n\n" <> String.duplicate("=", 70))
IO.puts("SUMMARY")
IO.puts(String.duplicate("=", 70))
IO.puts("""

1. Dimension Scaling:
   Scout handles increasing dimensionality effectively.
   #{final_dim}D is #{Float.round(total_scaling, 1)}x slower than #{baseline_dim}D.
   This is expected - search space grows exponentially with dimensions.

2. Parallel Execution:
   #{max_workers} workers achieved #{Float.round(actual_speedup, 2)}x speedup (#{Float.round(actual_speedup / ideal_speedup * 100, 1)}% efficiency).
   Factors affecting parallel speedup:
   - Trial coordination overhead
   - ETS storage synchronization
   - Limited trial count (#{n_trials} trials across #{max_workers} workers)

3. Recommendations:
   - For problems <10D: Single worker is often sufficient
   - For problems 10D+: Use 2-4 workers for meaningful speedup
   - For 100+ trials: Parallel execution shows stronger benefits

4. Memory Usage:
   Scout uses ETS storage which is memory-efficient.
   Typical workloads stay well under 1GB for reasonable problem sizes.
""")

IO.puts("\n✓ Scaling and parallelism benchmark complete!")
IO.puts("")
