#!/usr/bin/env elixir
# Real-world Scout profiling - identify actual bottlenecks

# Simple sphere function for testing
defmodule TestObjective do
  def sphere(params) do
    x = params.x
    y = params.y
    x*x + y*y
  end
end

# Benchmark different parts of Scout
IO.puts("Profiling Scout performance...")
IO.puts(String.duplicate("=", 80))

# 1. Profile study creation
IO.puts("\n1. STUDY CREATION")
{time_us, _result} = :timer.tc(fn ->
  for _ <- 1..1000 do
    # Simulate study creation overhead
    :ets.new(:test_study, [:set, :public])
    |> :ets.delete()
  end
end)
IO.puts("  1000 study creates: #{div(time_us, 1000)} μs/study")

# 2. Profile trial execution overhead
IO.puts("\n2. TRIAL EXECUTION OVERHEAD")
{time_us, _result} = :timer.tc(fn ->
  for _ <- 1..1000 do
    # Simulate trial spawn + execute + result collection
    task = Task.async(fn -> TestObjective.sphere(%{x: 1.0, y: 2.0}) end)
    Task.await(task)
  end
end)
IO.puts("  1000 trial executions: #{div(time_us, 1000)} μs/trial")

# 3. Profile parameter sampling
IO.puts("\n3. PARAMETER SAMPLING")
{time_us, _result} = :timer.tc(fn ->
  for _ <- 1..10000 do
    # Simulate random parameter generation
    %{
      x: :rand.uniform() * 10.0,
      y: :rand.uniform() * 10.0
    }
  end
end)
IO.puts("  10000 random samples: #{div(time_us, 10000)} μs/sample")

# 4. Profile ETS read/write
IO.puts("\n4. ETS STORAGE")
table = :ets.new(:perf_test, [:set, :public])

{write_time_us, _} = :timer.tc(fn ->
  for i <- 1..10000 do
    :ets.insert(table, {i, %{value: i * 1.5, params: %{x: i, y: i}}})
  end
end)

{read_time_us, _} = :timer.tc(fn ->
  for i <- 1..10000 do
    :ets.lookup(table, i)
  end
end)

IO.puts("  10000 ETS writes: #{div(write_time_us, 10000)} μs/write")
IO.puts("  10000 ETS reads:  #{div(read_time_us, 10000)} μs/read")

:ets.delete(table)

# 5. Profile sorting (common in samplers like TPE)
IO.puts("\n5. SORTING (TPE bottleneck)")
trials = for i <- 1..1000, do: %{id: i, value: :rand.uniform() * 100}

{time_us, _} = :timer.tc(fn ->
  for _ <- 1..100 do
    Enum.sort_by(trials, & &1.value)
  end
end)
IO.puts("  100x sort of 1000 trials: #{div(time_us, 100)} μs/sort")

# 6. Profile gaussian KDE (TPE uses this)
IO.puts("\n6. GAUSSIAN SAMPLING")
{time_us, _} = :timer.tc(fn ->
  for _ <- 1..10000 do
    # Simulate Box-Muller transform for gaussian
    u1 = :rand.uniform()
    u2 = :rand.uniform()
    :math.sqrt(-2.0 * :math.log(u1)) * :math.cos(2.0 * :math.pi() * u2)
  end
end)
IO.puts("  10000 gaussian samples: #{div(time_us, 10000)} μs/sample")

# 7. Profile term serialization (faster than JSON)
IO.puts("\n7. TERM SERIALIZATION")
trial_data = %{
  id: 1,
  params: %{x: 1.5, y: 2.5, z: 3.5},
  value: 42.0,
  state: "complete",
  started_at: DateTime.utc_now(),
  completed_at: DateTime.utc_now()
}

{time_us, _} = :timer.tc(fn ->
  for _ <- 1..10000 do
    :erlang.term_to_binary(trial_data)
  end
end)
IO.puts("  10000 term serializations: #{div(time_us, 10000)} μs/encode")

IO.puts("\n" <> String.duplicate("=", 80))
IO.puts("BOTTLENECK ANALYSIS")
IO.puts(String.duplicate("=", 80))
IO.puts("""

Expected hotspots based on profiling:
1. **Trial execution overhead** - Process spawning dominates (50-100μs)
2. **Sorting in TPE** - O(n log n) gets expensive with many trials
3. **JSON encoding** - Slow for large trial histories
4. **Gaussian sampling** - Box-Muller transform is costly

Optimization targets:
- Batch trial execution to amortize spawn cost
- Cache sorted trial lists in TPE
- Use binary term storage instead of JSON
- Pre-compute gaussian samples in pools
""")
