#!/usr/bin/env elixir

# Test enhanced visualizations
IO.puts("\n" <> String.duplicate("=", 60))
IO.puts(" ENHANCED VISUALIZATIONS TEST")
IO.puts(String.duplicate("=", 60))

IO.puts("\n1. Creating a study with many trials for visualization...")

# Create a complex optimization problem for better visualizations
result = Scout.Easy.optimize(
  fn params ->
    # Rosenbrock function (classic optimization test)
    x = params.x
    y = params.y
    z = params.z
    
    term1 = 100 * :math.pow(y - x*x, 2) + :math.pow(1 - x, 2)
    term2 = 100 * :math.pow(z - y*y, 2) + :math.pow(1 - y, 2)
    term1 + term2
  end,
  %{
    x: {:uniform, -2, 2},
    y: {:uniform, -2, 2},
    z: {:uniform, -2, 2}
  },
  n_trials: 30,
  study_id: "visualization-test-#{:rand.uniform(1000)}",
  parallelism: 3
)

IO.puts("   ✓ Optimization completed")
IO.puts("   Study ID: #{result.study_id}")
IO.puts("   Best value: #{Float.round(result.best_value, 4)}")
IO.puts("   Total trials: #{result.n_trials}")

IO.puts("\n2. Visualization URLs:")
IO.puts("   Standard Dashboard:")
IO.puts("   http://localhost:4050/studies/#{result.study_id}")
IO.puts("")
IO.puts("   📊 Enhanced Visualizations:")
IO.puts("   http://localhost:4050/visualizations/#{result.study_id}")
IO.puts("")
IO.puts("   ⚡ Adaptive Dashboard:")
IO.puts("   http://localhost:4050/adaptive/#{result.study_id}")

IO.puts("\n3. Available Visualizations:")
IO.puts("   • Convergence Plot - Shows how the best value improves over time")
IO.puts("   • Parameter Importance - Identifies which parameters most affect the outcome")
IO.puts("   • Optimization Heatmap - Visual timeline of optimization quality")
IO.puts("   • Parallel Coordinates - Multi-dimensional parameter visualization")

IO.puts("\n4. Understanding the Visualizations:")

IO.puts("\n   📈 Convergence Plot:")
IO.puts("   - X-axis: Trial number")
IO.puts("   - Y-axis: Best value found so far")
IO.puts("   - Shows optimization progress and when it plateaus")

IO.puts("\n   🎯 Parameter Importance:")
IO.puts("   - Calculated using correlation analysis")
IO.puts("   - Higher bars = parameters with more impact")
IO.puts("   - Helps identify which hyperparameters matter most")

IO.puts("\n   🌡️ Optimization Heatmap:")
IO.puts("   - Time flows left to right")
IO.puts("   - Color shows optimization quality (blue=good, red=bad)")
IO.puts("   - Identifies periods of good/bad exploration")

IO.puts("\n   📐 Parallel Coordinates:")
IO.puts("   - Each vertical line is a parameter")
IO.puts("   - Lines connect parameter values for each trial")
IO.puts("   - Color indicates objective value quality")

# Export data for external analysis
{:ok, json_data} = Scout.Export.to_json(result.study_id)
{:ok, stats} = Scout.Export.study_stats(result.study_id)

IO.puts("\n5. Export Statistics:")
IO.puts("   Best value: #{stats.best_value}")
IO.puts("   Mean value: #{Float.round(stats.mean_value, 4)}")
IO.puts("   Std deviation: #{Float.round(stats.std_dev, 4)}")
IO.puts("   Success rate: #{Float.round(stats.success_rate * 100, 1)}%")

IO.puts("\n✅ Visualization test complete!")
IO.puts("   Visit the URLs above to see the enhanced visualizations.")
IO.puts("   The visualizations update in real-time as optimization progresses.")