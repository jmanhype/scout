# Test Scout Dashboard with Real Optimization
# This runs an actual optimization and shows it in the dashboard

IO.puts("\n=== Scout Live Dashboard Test ===\n")

# Start both apps
Application.ensure_all_started(:scout_core)
Application.ensure_all_started(:scout_dashboard)

IO.puts("✓ Scout core started")
IO.puts("✓ Dashboard started at http://localhost:4050")

# Run an optimization in the background
task = Task.async(fn ->
  result = Scout.Easy.optimize(
    fn params ->
      # Simple sphere function: minimize x² + y²
      x = params.x
      y = params.y

      # Add some delay so we can watch it in the dashboard
      Process.sleep(100)

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

  IO.puts("\n=== Optimization Complete ===")
  IO.puts("Study ID: #{result.study_name}")
  IO.puts("Best value: #{:io_lib.format("~.6f", [result.best_score])}")
  IO.puts("Best params: #{inspect(result.best_params)}")

  result
end)

IO.puts("\nStarting optimization...")
IO.puts("Open http://localhost:4050 to watch live!")
IO.puts("Press Ctrl+C twice to stop\n")

# Wait for the optimization
Task.await(task, :infinity)

# Keep dashboard running
Process.sleep(:infinity)
