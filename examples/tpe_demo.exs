# TPE (Tree-structured Parzen Estimator) Demo
#
# This example demonstrates Scout's TPE sampler, which learns from
# historical trials to intelligently explore the search space.
#
# TPE is recommended for most hyperparameter optimization tasks as it:
# - Learns from previous trials
# - Handles mixed parameter types (continuous, discrete, categorical)
# - Converges faster than random search on most problems
#
# Run: mix run examples/tpe_demo.exs

# Ensure Scout is started
Application.ensure_all_started(:scout_core)

IO.puts("\n=== TPE Sampler Demo ===\n")

# Define a challenging objective: Rosenbrock function
# This has a narrow curved valley that's hard for random search
objective = fn params ->
  x = params.x
  y = params.y
  (1 - x) ** 2 + 100 * (y - x ** 2) ** 2
end

# Search space
search_space = %{
  x: {:uniform, -2.0, 2.0},
  y: {:uniform, -1.0, 3.0}
}

IO.puts("Objective: Rosenbrock function (narrow valley)")
IO.puts("Search space: x ∈ [-2, 2], y ∈ [-1, 3]")
IO.puts("Global optimum: f(1, 1) = 0\n")

# Compare Random vs TPE
IO.puts("Running Random sampler (baseline)...")

random_result =
  Scout.Easy.optimize(
    objective,
    search_space,
    n_trials: 50,
    sampler: :random,
    seed: 42
  )

IO.puts("Random Search - Best value: #{Float.round(random_result.best_value, 6)}")
IO.puts("Random Search - Best params: x=#{Float.round(random_result.best_params.x, 4)}, y=#{Float.round(random_result.best_params.y, 4)}\n")

IO.puts("Running TPE sampler (intelligent)...")

tpe_result =
  Scout.Easy.optimize(
    objective,
    search_space,
    n_trials: 50,
    sampler: :tpe,
    seed: 42,
    sampler_opts: %{
      # Number of random trials before TPE starts learning
      n_startup_trials: 10,
      # Number of candidates to evaluate with Expected Improvement
      n_ei_candidates: 24
    }
  )

IO.puts("TPE - Best value: #{Float.round(tpe_result.best_value, 6)}")
IO.puts("TPE - Best params: x=#{Float.round(tpe_result.best_params.x, 4)}, y=#{Float.round(tpe_result.best_params.y, 4)}\n")

# Show improvement
improvement = (random_result.best_value - tpe_result.best_value) / random_result.best_value * 100

IO.puts("=== Results ===")
IO.puts("TPE improvement over Random: #{Float.round(improvement, 1)}%")
IO.puts(
  "TPE found a solution #{Float.round(random_result.best_value / tpe_result.best_value, 2)}x closer to optimal"
)

IO.puts("\n✅ TPE Demo Complete!")
IO.puts(
  "Tip: TPE is the default sampler in Optuna and works well for most optimization problems."
)
