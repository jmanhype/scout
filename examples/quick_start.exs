# Scout Quick Start - No Database Required!
# Just compile and run: mix run quick_start.exs

# Start only scout_core (not dashboard)
Application.ensure_all_started(:scout_core)

IO.puts("\n=== Scout Quick Start ===\n")
IO.puts("Finding minimum of f(x,y) = x² + y²")
IO.puts("Expected optimum: x=0, y=0, value=0\n")

# Run optimization
result = Scout.Easy.optimize(
  fn params ->
    x = params.x
    y = params.y
    x * x + y * y
  end,
  %{
    x: {:uniform, -5.0, 5.0},
    y: {:uniform, -5.0, 5.0}
  },
  n_trials: 50,
  sampler: :random,
  direction: :minimize
)

# Show results
IO.puts("\n=== Results ===")
IO.puts("Best value: #{:io_lib.format("~.6f", [result.best_score])}")
IO.puts("Best x:     #{:io_lib.format("~.6f", [result.best_params.x])}")
IO.puts("Best y:     #{:io_lib.format("~.6f", [result.best_params.y])}")

success = result.best_score < 1.0
IO.puts("\nStatus: #{if success, do: "SUCCESS ✓", else: "OK (try more trials)"}")
IO.puts("\nScout is working! No database required.\n")
