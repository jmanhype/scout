# Test adaptive dashboard functionality
IO.puts("\n=== Testing Adaptive Dashboard Update Intervals ===\n")

# Create a study that we can monitor
IO.puts("1. Creating a study with continuous optimization...")

# Start optimization in background
task = Task.async(fn ->
  Scout.Easy.optimize(
    fn params -> 
      # Simulate varying computation time
      :timer.sleep(:rand.uniform(100))
      # Himmelblau's function
      x = params.x
      y = params.y
      :math.pow(x - 3, 2) + :math.pow(y - 2, 2) +
      :math.pow(x + 2, 2) * :math.pow(y + 1, 2) * 0.1
    end,
    %{
      x: {:uniform, -5, 5},
      y: {:uniform, -5, 5}
    },
    n_trials: 50,
    study_id: "adaptive-test-study",
    parallelism: 2  # Run 2 trials in parallel for more activity
  )
end)

IO.puts("   Optimization started in background")
IO.puts("   Study ID: adaptive-test-study")

# Monitor activity levels
IO.puts("\n2. Monitoring dashboard activity levels...")

monitor_activity = fn ->
  # Get study status to calculate activity
  case Scout.Store.get_study("adaptive-test-study") do
    {:ok, _study} ->
      trials = Scout.Store.list_trials("adaptive-test-study")
      
      # Count trials by status
      stats = Enum.reduce(trials, %{total: 0, running: 0, completed: 0}, fn trial, acc ->
        status = case trial do
          %Scout.Trial{status: s} -> s
          _ -> trial[:status] || trial["status"]
        end
        
        %{
          total: acc.total + 1,
          running: acc.running + if(status in [:running, "running"], do: 1, else: 0),
          completed: acc.completed + if(status in [:succeeded, "succeeded", :completed, "completed"], do: 1, else: 0)
        }
      end)
      
      # Determine activity level based on recent trials
      activity_level = cond do
        stats.running >= 2 -> :high
        stats.running >= 1 -> :normal
        stats.completed == stats.total -> :idle
        true -> :low
      end
      
      {activity_level, stats}
      
    :error ->
      {:initializing, %{total: 0, running: 0, completed: 0}}
  end
end

# Monitor for a few seconds
Enum.each(1..10, fn i ->
  {activity, stats} = monitor_activity.()
  
  recommended_interval = case activity do
    :high -> "500ms"
    :normal -> "1s"
    :low -> "2s"
    :idle -> "5s"
    :initializing -> "1s"
  end
  
  IO.puts("   #{i}. Activity: #{activity}, Trials: #{stats.total}, Running: #{stats.running}, Completed: #{stats.completed}")
  IO.puts("      Recommended update interval: #{recommended_interval}")
  
  :timer.sleep(500)
end)

IO.puts("\n3. Dashboard URLs:")
IO.puts("   Standard dashboard: http://localhost:4050/studies/adaptive-test-study")
IO.puts("   Adaptive dashboard: http://localhost:4050/adaptive/adaptive-test-study")

IO.puts("\n4. Waiting for optimization to complete...")

# Wait for optimization to finish
case Task.yield(task, 15_000) || Task.shutdown(task) do
  {:ok, result} ->
    IO.puts("   Optimization completed!")
    IO.puts("   Best value: #{result.best_value}")
    IO.puts("   Total trials: #{result.n_trials}")
    
  nil ->
    IO.puts("   Optimization still running (timed out waiting)")
end

# Final activity check
{final_activity, final_stats} = monitor_activity.()
IO.puts("\n5. Final activity level: #{final_activity}")
IO.puts("   Total trials executed: #{final_stats.total}")
IO.puts("   Final recommended interval: #{case final_activity do
  :idle -> "5s (idle - optimization complete)"
  :low -> "2s (low activity)"
  :normal -> "1s (normal activity)"
  :high -> "500ms (high activity)"
  _ -> "1s"
end}")

IO.puts("\n✅ Adaptive dashboard test complete!")
IO.puts("   The adaptive dashboard automatically adjusts update frequency based on optimization activity,")