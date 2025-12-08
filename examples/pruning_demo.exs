# Pruning Demo - Early Stopping for Expensive Trials
#
# This example demonstrates Scout's pruning capabilities, which can save
# 30-70% of computation time by stopping unpromising trials early.
#
# Pruning is essential for:
# - Deep learning (stop bad hyperparameters after a few epochs)
# - Expensive simulations (stop poor configurations early)
# - Long-running optimizations (maximize trial throughput)
#
# Run: mix run examples/pruning_demo.exs

Application.ensure_all_started(:scout_core)

IO.puts("\n=== Pruning Demo ===\n")

# Simulate training a model with intermediate results
# In real ML: epochs would be actual training iterations
defmodule SimulatedTraining do
  # Simulate a learning curve based on hyperparameters
  def train(learning_rate, n_layers, report_fn) do
    # Bad hyperparameters plateau early
    quality = learning_rate * n_layers

    for epoch <- 1..20 do
      # Simulate training progress (better params improve faster)
      loss = 10.0 / (1.0 + epoch * quality) + :rand.uniform() * 0.1

      # Report intermediate value to pruner
      case report_fn.(loss, epoch) do
        :continue ->
          :ok

        :prune ->
          IO.puts("  ⚡ Trial pruned at epoch #{epoch} (loss: #{Float.round(loss, 3)})")
          throw({:pruned, epoch})
      end
    end

    # Final loss after 20 epochs
    10.0 / (1.0 + 20 * quality)
  end
end

# Objective function with pruning support
objective_with_pruning = fn params, report_fn ->
  try do
    SimulatedTraining.train(params.learning_rate, params.n_layers, report_fn)
  catch
    {:pruned, _epoch} -> :infinity
  end
end

search_space = %{
  learning_rate: {:log_uniform, 1.0e-4, 1.0e-1},
  n_layers: {:int, 2, 8}
}

IO.puts("Simulating neural network training with 20 epochs per trial\n")

# Baseline: No pruning
IO.puts("=== Baseline: No Pruning ===")
start_time = System.monotonic_time(:millisecond)

baseline_result =
  Scout.Easy.optimize(
    fn params ->
      # No report_fn provided, so no pruning
      quality = params.learning_rate * params.n_layers

      Enum.reduce(1..20, 0, fn epoch, _acc ->
        10.0 / (1.0 + epoch * quality)
      end)
    end,
    search_space,
    n_trials: 30,
    sampler: :random,
    seed: 42
  )

baseline_time = System.monotonic_time(:millisecond) - start_time

IO.puts("Completed 30 trials in #{baseline_time}ms")
IO.puts("Best value: #{Float.round(baseline_result.best_value, 6)}\n")

# With MedianPruner
IO.puts("=== With Median Pruner (Aggressive) ===")
start_time = System.monotonic_time(:millisecond)

pruned_result =
  Scout.Easy.optimize(
    objective_with_pruning,
    search_space,
    n_trials: 30,
    sampler: :random,
    pruner: :median,
    pruner_opts: %{
      # Don't prune first 5 trials (need history)
      n_startup_trials: 5,
      # Don't prune before epoch 3
      n_warmup_steps: 3
    },
    seed: 42
  )

pruned_time = System.monotonic_time(:millisecond) - start_time

IO.puts("Completed 30 trials in #{pruned_time}ms")
IO.puts("Best value: #{Float.round(pruned_result.best_value, 6)}\n")

# Show savings
time_saved = baseline_time - pruned_time
savings_pct = time_saved / baseline_time * 100

IO.puts("=== Results ===")
IO.puts("Time saved: #{time_saved}ms (#{Float.round(savings_pct, 1)}% faster)")
IO.puts("Quality loss: #{Float.round(abs(baseline_result.best_value - pruned_result.best_value), 6)}")

if savings_pct > 20 do
  IO.puts("\n✅ Pruning saved significant computation time!")
else
  IO.puts("\n⚠️  Savings lower than expected (simulated workload too fast)")
end

IO.puts("\nAvailable Pruners:")
IO.puts("  :median      - Stop if worse than median (aggressive, 30-50% savings)")
IO.puts("  :percentile  - Stop if below percentile (conservative, 20-40% savings)")
IO.puts("  :hyperband   - Adaptive resource allocation (40-70% savings)")
IO.puts(
  "  :successive_halving - Bracket-based pruning (similar to Hyperband)"
)

IO.puts("\n💡 Tip: Use Hyperband for deep learning, Median for general optimization")
