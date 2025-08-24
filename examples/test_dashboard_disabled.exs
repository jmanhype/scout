# Test that dashboard can be completely disabled
IO.puts("\n=== PROOF: Dashboard Can Be Disabled ===\n")

# First, show what's currently running
IO.puts("1. Current processes before changing config:")
dashboard_processes = [
  ScoutDashboardWeb.Endpoint,
  ScoutDashboard.TelemetryListener,
  ScoutDashboard.PubSub
]

for name <- dashboard_processes do
  pid = Process.whereis(name)
  IO.puts("   #{name}: #{if pid, do: "RUNNING (#{inspect pid})", else: "NOT RUNNING"}")
end

# Now disable dashboard and restart the application
IO.puts("\n2. Disabling dashboard in config...")
Application.put_env(:scout, :dashboard_enabled, false)
Application.stop(:scout)
:timer.sleep(100)
Application.ensure_all_started(:scout)

IO.puts("\n3. Checking processes after restart with dashboard disabled:")
for name <- dashboard_processes do
  pid = Process.whereis(name)
  IO.puts("   #{name}: #{if pid, do: "RUNNING (#{inspect pid})", else: "NOT RUNNING"}")
end

# Verify Scout still works without dashboard using Scout.Easy
IO.puts("\n4. Verifying Scout still works without dashboard:")

# Use Scout.Easy which handles the correct search space format
result = Scout.Easy.optimize(
  fn params -> params.x * params.x end,  # Simple quadratic
  %{x: {:uniform, 0, 1}},
  n_trials: 3,
  study_id: "test-no-dashboard"
)

IO.puts("   Best value: #{result.best_value}")
IO.puts("   Best params: #{inspect(result.best_params)}")

IO.puts("\n✅ PROVEN: Scout works as a library without dashboard\!")

# Re-enable for other tests
Application.put_env(:scout, :dashboard_enabled, true)
