# Distributed Optimization Demo
#
# This example demonstrates Scout's distributed optimization capabilities
# using BEAM's built-in clustering and Oban job queue.
#
# Benefits of distributed optimization:
# - Scale horizontally across multiple machines
# - Fault tolerance (nodes can fail without losing study)
# - Better resource utilization for expensive trials
# - Persistent job queue survives restarts
#
# Run: mix run examples/distributed_demo.exs

Application.ensure_all_started(:scout_core)

IO.puts("\n=== Distributed Optimization Demo ===\n")

# For demo purposes, we'll simulate local parallelism
# In production, you'd connect to remote nodes:
#   Node.connect(:"worker@server1")
#   Node.connect(:"worker@server2")

IO.puts("Current node: #{node()}")
IO.puts("Connected nodes: #{inspect(Node.list())}\n")

if Node.list() == [] do
  IO.puts("⚠️  No remote nodes connected (running in single-node mode)")
  IO.puts("To enable true distributed optimization:")
  IO.puts("  1. Start multiple nodes with --sname or --name")
  IO.puts("  2. Connect them with Node.connect/1")
  IO.puts("  3. Ensure PostgreSQL is configured (shared state)\n")
end

# Define a moderately expensive objective
objective = fn params ->
  # Simulate computation (e.g., model training)
  Process.sleep(100)

  x = params.x
  y = params.y
  # Sphere function
  x * x + y * y
end

search_space = %{
  x: {:uniform, -5.0, 5.0},
  y: {:uniform, -5.0, 5.0}
}

# Sequential execution (baseline)
IO.puts("=== Sequential Execution (Baseline) ===")
start_time = System.monotonic_time(:millisecond)

sequential_result =
  Scout.Easy.optimize(
    objective,
    search_space,
    n_trials: 20,
    parallelism: 1,
    # Use ETS for local demo
    seed: 42
  )

sequential_time = System.monotonic_time(:millisecond) - start_time

IO.puts("Time: #{sequential_time}ms")
IO.puts("Best value: #{Float.round(sequential_result.best_value, 6)}\n")

# Parallel execution (simulates distributed)
IO.puts("=== Parallel Execution (4 workers) ===")
start_time = System.monotonic_time(:millisecond)

parallel_result =
  Scout.Easy.optimize(
    objective,
    search_space,
    n_trials: 20,
    parallelism: 4,
    # In production with Oban:
    # executor: Scout.Executor.Oban
    seed: 42
  )

parallel_time = System.monotonic_time(:millisecond) - start_time

IO.puts("Time: #{parallel_time}ms")
IO.puts("Best value: #{Float.round(parallel_result.best_value, 6)}\n")

# Calculate speedup
speedup = sequential_time / parallel_time
efficiency = speedup / 4 * 100

IO.puts("=== Results ===")
IO.puts("Speedup: #{Float.round(speedup, 2)}x")
IO.puts("Parallel efficiency: #{Float.round(efficiency, 1)}%")

if speedup > 2.5 do
  IO.puts("✅ Good parallel scaling!")
else
  IO.puts("⚠️  Parallel efficiency could be better (objective too fast)")
end

IO.puts("\n=== Production Distributed Setup ===\n")

IO.puts("""
For multi-node distributed optimization:

1. Configure PostgreSQL (shared storage):
   config :scout_core, Scout.Repo,
     database: "scout_production",
     hostname: "db.example.com",
     pool_size: 10

2. Configure Oban (distributed job queue):
   config :scout_core, Oban,
     repo: Scout.Repo,
     queues: [default: 10]

3. Start nodes with clustering:
   # Node 1 (coordinator)
   iex --sname coord@server1 -S mix

   # Node 2 (worker)
   iex --sname worker@server2 -S mix

4. Connect nodes:
   # In coord@server1
   Node.connect(:"worker@server2")

5. Run distributed optimization:
   Scout.Easy.optimize(
     expensive_objective,
     search_space,
     n_trials: 1000,
     parallelism: 20,        # Spans all connected nodes
     executor: :oban         # Persistent queue
   )
""")

IO.puts("💡 Tips:")
IO.puts("  - Use PostgreSQL for shared study state across nodes")
IO.puts("  - Oban provides fault tolerance and job persistence")
IO.puts("  - BEAM clustering handles node communication automatically")
IO.puts("  - Each node can have different hardware (GPUs, memory, etc.)")
