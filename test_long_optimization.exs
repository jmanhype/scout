# Test script for Scout Live Dashboard with longer optimization
# This runs a slower optimization so you can see it in the dashboard

# Start the dashboard
{:ok, _} = Application.ensure_all_started(:scout_dashboard)

IO.puts("\n=== Scout Live Dashboard Test ===\n")
IO.puts("✓ Scout core started")
IO.puts("✓ Dashboard started at http://localhost:4050")

# Define objective function with artificial delay
objective_fn = fn params ->
  # Sleep for 2 seconds per trial to make it observable
  Process.sleep(2000)

  # Sphere function: minimize x^2 + y^2
  x = Map.get(params, :x, 0.0)
  y = Map.get(params, :y, 0.0)

  result = x * x + y * y
  IO.puts("  Trial: x=#{Float.round(x, 3)}, y=#{Float.round(y, 3)} -> #{Float.round(result, 6)}")
  result
end

# Run optimization in background task
task = Task.async(fn ->
  result = Scout.Easy.optimize(
    objective_fn,
    %{
      x: {:uniform, -5.0, 5.0},
      y: {:uniform, -5.0, 5.0}
    },
    n_trials: 20,  # 20 trials × 2 seconds = ~40 seconds
    sampler: :tpe,
    direction: :minimize
  )

  IO.puts("\n=== Optimization Complete ===")
  IO.puts("Study ID: #{result.study_name}")
  IO.puts("Best value: #{:io_lib.format("~.6f", [result.best_score])}")
  IO.puts("Best params: #{inspect(result.best_params)}")
  IO.puts("\n✓ Study will remain visible in dashboard")

  result
end)

IO.puts("\nStarting optimization (20 trials × 2sec = ~40 seconds)...")
IO.puts("Open http://localhost:4050 to watch live!")
IO.puts("Press Ctrl+C twice to stop\n")

# Wait for completion
Task.await(task, :infinity)

# Keep process alive so study stays in ETS
IO.puts("\n✓ Keeping dashboard running. Press Ctrl+C to exit.")
Process.sleep(:infinity)
