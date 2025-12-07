# Test Scout Dashboard with synthetic data
# Run: mix run test_dashboard.exs

IO.puts("\n=== Starting Scout Dashboard ===\n")
IO.puts("Starting scout_core...")
Application.ensure_all_started(:scout_core)

IO.puts("Starting scout_dashboard...")
Application.ensure_all_started(:scout_dashboard)

IO.puts("\n✓ Dashboard should be running at: http://localhost:4050")
IO.puts("\nPress Ctrl+C twice to stop\n")

# Keep the script running
Process.sleep(:infinity)
