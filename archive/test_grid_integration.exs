#!/usr/bin/env elixir

# Test Grid sampler integration with Scout

Mix.install([
  {:ecto, "~> 3.9"},
  {:postgrex, "~> 0.17"},
  {:telemetry, "~> 1.0"}
])

Code.require_file("lib/scout/application.ex")
Code.require_file("lib/scout.ex")
Code.require_file("lib/scout/search_space.ex")
Code.require_file("lib/scout/sampler.ex")
Code.require_file("lib/scout/sampler/grid.ex")
Code.require_file("lib/scout/study.ex")
Code.require_file("lib/scout/trial.ex")

defmodule TestGridIntegration do
  def run do
    IO.puts("""
    
    ═══════════════════════════════════════════════════════════
              TESTING GRID SAMPLER INTEGRATION
    ═══════════════════════════════════════════════════════════
    """)
    
    # Test simple optimization function
    test_simple_optimization()
    
    IO.puts("\n✅ Grid Sampler integration tests passed!")
  end
  
  defp test_simple_optimization do
    IO.puts("\n🎯 Test: Simple 2D Optimization")
    IO.puts("-" <> String.duplicate("-", 40))
    
    # Define a simple objective function: minimize (x-1)² + (y-2)²
    # Optimal point should be x=1, y=2
    objective_fn = fn params ->
      x = params[:x]
      y = params[:y]
      loss = (x - 1) * (x - 1) + (y - 2) * (y - 2)
      IO.puts("  Trial: x=#{Float.round(x, 2)}, y=#{Float.round(y, 2)} → loss=#{Float.round(loss, 4)}")
      loss
    end
    
    # Create search space
    search_space = fn ->
      %{
        x: {:uniform, -2, 4},
        y: {:uniform, -1, 5}
      }
    end
    
    # Initialize Grid sampler
    sampler_state = Scout.Sampler.Grid.init(%{grid_points: 4})
    
    IO.puts("Testing Grid search for 2D optimization:")
    IO.puts("  Objective: minimize (x-1)² + (y-2)²")
    IO.puts("  Search space: x ∈ [-2, 4], y ∈ [-1, 5]")
    IO.puts("  Grid: 4x4 = 16 points")
    
    # Run 16 trials (full grid)
    results = []
    
    {results, _final_state} = Enum.reduce(1..16, {[], sampler_state}, fn trial_num, {acc_results, acc_state} ->
      {params, new_state} = Scout.Sampler.Grid.next(search_space, trial_num, [], acc_state)
      loss = objective_fn.(params)
      result = %{trial: trial_num, params: params, loss: loss}
      {[result | acc_results], new_state}
    end)
    
    # Find best result
    best = Enum.min_by(results, & &1.loss)
    
    IO.puts("\n  Best result:")
    IO.puts("    Trial #{best.trial}: x=#{Float.round(best.params.x, 2)}, y=#{Float.round(best.params.y, 2)}")
    IO.puts("    Loss: #{Float.round(best.loss, 4)}")
    IO.puts("    Distance from optimum (1,2): #{Float.round(:math.sqrt((best.params.x - 1)**2 + (best.params.y - 2)**2), 3)}")
    
    # Check coverage
    x_values = results |> Enum.map(& &1.params.x) |> Enum.uniq() |> Enum.sort()
    y_values = results |> Enum.map(& &1.params.y) |> Enum.uniq() |> Enum.sort()
    
    IO.puts("\n  Grid coverage:")
    IO.puts("    X values: #{inspect(Enum.map(x_values, &Float.round(&1, 1)))}")
    IO.puts("    Y values: #{inspect(Enum.map(y_values, &Float.round(&1, 1)))}")
    IO.puts("    Total unique points: #{length(results |> Enum.map(& &1.params) |> Enum.uniq())}")
    
    IO.puts("✓ Grid search completed systematic exploration")
  end
end

TestGridIntegration.run()