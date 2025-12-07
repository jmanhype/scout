# Scout Pruner Effectiveness Benchmark
# Demonstrates pruner configuration and basic validation
#
# Usage:
#   mix run benchmark/pruner_effectiveness.exs
#
# Note: Full pruning effectiveness requires objectives with intermediate value reporting,
# which is an advanced feature. This benchmark demonstrates pruner configuration and
# provides a framework for future pruning benchmarks.

Code.require_file("util.exs", __DIR__)
alias Benchmark.Util

# Print environment
Util.print_env_info()

IO.puts("Pruner Effectiveness Benchmark")
IO.puts("=" |> String.duplicate(70))
IO.puts("\nTesting: Median, Percentile, Hyperband, SuccessiveHalving")
IO.puts("This benchmark demonstrates pruner configuration.\n")

# Test configurations
pruners = [
  {nil, "No Pruning (Baseline)"},
  {:median, "Median Pruner"},
  {:percentile, "Percentile Pruner"},
  {:hyperband, "Hyperband"},
  {Scout.Pruner.SuccessiveHalving, "SuccessiveHalving"}
]

# Use a moderately complex function to show pruning potential
space = Util.continuous_space(5, -5.12, 5.12)
n_trials = 30
seed = 42

IO.puts("Configuration:")
IO.puts("  Function: Rastrigin 5D (multimodal, challenging)")
IO.puts("  Trials: #{n_trials}")
IO.puts("  Seed: #{seed}\n")

# Run with each pruner
results = for {pruner, name} <- pruners do
  IO.puts("\n" <> String.duplicate("-", 70))
  IO.puts("Testing: #{name}")
  IO.puts(String.duplicate("-", 70))

  start_time = System.monotonic_time(:millisecond)

  opts = [
    n_trials: n_trials,
    sampler: :tpe,
    direction: :minimize,
    seed: seed
  ]

  opts = if pruner != nil do
    Keyword.put(opts, :pruner, pruner)
  else
    opts
  end

  result = Scout.Easy.optimize(
    &Util.rastrigin/1,
    space,
    opts
  )

  end_time = System.monotonic_time(:millisecond)
  duration = end_time - start_time

  best_value = result.best_value || :infinity

  IO.puts("  Best value: #{Float.round(best_value, 6)}")
  IO.puts("  Time: #{duration}ms")
  IO.puts("  Best params: #{inspect(result.best_params)}")

  {name, best_value, duration, result.n_trials || n_trials}
end

# Summary Report
IO.puts("\n\n" <> String.duplicate("=", 70))
IO.puts("SUMMARY")
IO.puts(String.duplicate("=", 70))

IO.puts("\n| Pruner | Best Value | Time (ms) | Trials |")
IO.puts("|--------|------------|-----------|--------|")

for {name, best_value, duration, trials_completed} <- results do
  val_str = if best_value == :infinity, do: "infinity", else: Float.round(best_value, 4) |> Float.to_string()
  IO.puts("| #{String.pad_trailing(name, 22)} | #{String.pad_leading(val_str, 10)} | #{String.pad_leading(Integer.to_string(duration), 9)} | #{String.pad_leading(Integer.to_string(trials_completed), 6)} |")
end

IO.puts("\n" <> String.duplicate("=", 70))
IO.puts("Notes:")
IO.puts("=" |> String.duplicate(70))
IO.puts("""
1. Pruner Configuration Validated: All pruners initialized successfully

2. Intermediate Value Reporting:
   Full pruning effectiveness requires objectives that report intermediate
   values at checkpoints. This is an advanced feature for iterative algorithms
   like neural network training.

   Example pruning-aware objective:
   ```elixir
   def train_model(params, report_fn) do
     for epoch <- 1..100 do
       loss = train_epoch(params, epoch)
       report_fn.(epoch, loss)  # Pruner checks this
     end
     final_loss
   end
   ```

3. Expected Pruning Benefits:
   - SuccessiveHalving: Aggressive early stopping, fastest but may miss good trials
   - Hyperband: Adaptive resource allocation across multiple budgets
   - Median: Prunes trials below median performance at each step
   - Percentile: More conservative, prunes bottom percentile

4. Typical Savings:
   With proper intermediate reporting, pruners can save 30-70% of compute
   time while maintaining 95%+ solution quality.

5. Next Steps:
   Implement iterative objective functions with intermediate reporting to
   fully demonstrate pruner effectiveness.
""")

IO.puts("\n✓ Pruner configuration benchmark complete!")
IO.puts("")
