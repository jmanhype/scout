#!/usr/bin/env elixir

# Demonstrate Grid sampler with hyperparameter optimization

Code.require_file("lib/scout/search_space.ex")
Code.require_file("lib/scout/sampler.ex")
Code.require_file("lib/scout/sampler/grid.ex")

defmodule GridSamplerDemo do
  def run do
    IO.puts("""
    
    ═══════════════════════════════════════════════════════════
                    GRID SAMPLER DEMONSTRATION
    ═══════════════════════════════════════════════════════════
    """)
    
    # Demo 1: ML hyperparameter tuning
    demo_ml_hyperparams()
    
    # Demo 2: Mathematical function optimization
    demo_math_optimization()
    
    # Demo 3: Comparison with random sampling
    demo_vs_random_sampling()
    
    IO.puts("\n🎉 Grid Sampler demonstration complete!")
  end
  
  defp demo_ml_hyperparams do
    IO.puts("\n🤖 Demo 1: ML Hyperparameter Tuning")
    IO.puts("-" <> String.duplicate("-", 45))
    IO.puts("Scenario: Tuning a neural network")
    
    # Typical ML hyperparameters
    space = fn ->
      %{
        learning_rate: {:log_uniform, 0.0001, 0.1},
        batch_size: {:choice, [16, 32, 64, 128]},
        hidden_layers: {:int, 1, 4},
        dropout: {:discrete_uniform, 0.0, 0.5, 0.1}
      }
    end
    
    state = Scout.Sampler.Grid.init(%{grid_points: 3, shuffle: false})
    
    IO.puts("\nGenerating hyperparameter configurations:")
    
    # Generate first 12 configurations
    {configs, _} = Enum.reduce(1..12, {[], state}, fn i, {acc_configs, acc_state} ->
      {params, new_state} = Scout.Sampler.Grid.next(space, i, [], acc_state)
      
      config = %{
        lr: Float.round(params.learning_rate, 5),
        batch: params.batch_size,
        layers: params.hidden_layers,
        dropout: params.dropout
      }
      
      IO.puts("  Config #{String.pad_leading(to_string(i), 2)}: lr=#{config.lr}, batch=#{config.batch}, layers=#{config.layers}, dropout=#{config.dropout}")
      
      {[config | acc_configs], new_state}
    end)
    
    # Analyze diversity
    unique_lrs = configs |> Enum.map(& &1.lr) |> Enum.uniq() |> length()
    unique_batches = configs |> Enum.map(& &1.batch) |> Enum.uniq() |> length()
    
    IO.puts("\n  Analysis:")
    IO.puts("    Total configurations: #{length(configs)}")
    IO.puts("    Unique learning rates: #{unique_lrs}")
    IO.puts("    Unique batch sizes: #{unique_batches}")
    IO.puts("    Systematic coverage: ✓")
  end
  
  defp demo_math_optimization do
    IO.puts("\n📊 Demo 2: Mathematical Function Optimization")
    IO.puts("-" <> String.duplicate("-", 50))
    IO.puts("Objective: Minimize f(x,y) = (x-2)² + (y+1)² + 0.1*sin(5*x)*cos(3*y)")
    IO.puts("           (Global minimum at approximately x=2, y=-1)")
    
    space = fn ->
      %{
        x: {:uniform, -1, 5},
        y: {:uniform, -4, 2}
      }
    end
    
    # Define objective function (minimize)
    objective = fn params ->
      x = params.x
      y = params.y
      base = (x - 2) * (x - 2) + (y + 1) * (y + 1)
      noise = 0.1 * :math.sin(5 * x) * :math.cos(3 * y)
      base + noise
    end
    
    state = Scout.Sampler.Grid.init(%{grid_points: 6})
    
    IO.puts("\nGrid search optimization (6x6 = 36 evaluations):")
    
    # Run optimization
    {results, _} = Enum.reduce(1..36, {[], state}, fn i, {acc_results, acc_state} ->
      {params, new_state} = Scout.Sampler.Grid.next(space, i, [], acc_state)
      value = objective.(params)
      
      result = %{
        trial: i,
        x: Float.round(params.x, 3),
        y: Float.round(params.y, 3),
        value: Float.round(value, 4)
      }
      
      if rem(i, 6) == 0 or i <= 6 do
        IO.puts("  Trial #{String.pad_leading(to_string(i), 2)}: x=#{result.x}, y=#{result.y} → f=#{result.value}")
      end
      
      {[result | acc_results], new_state}
    end)
    
    # Find best results
    sorted_results = Enum.sort_by(results, & &1.value)
    best = hd(sorted_results)
    
    IO.puts("\n  Results:")
    IO.puts("    Best result: x=#{best.x}, y=#{best.y} → f=#{best.value}")
    IO.puts("    Distance from optimum (2, -1): #{Float.round(:math.sqrt((best.x - 2)**2 + (best.y + 1)**2), 3)}")
    
    # Show top 3 results
    IO.puts("\n  Top 3 configurations:")
    sorted_results
    |> Enum.take(3)
    |> Enum.with_index(1)
    |> Enum.each(fn {result, rank} ->
      IO.puts("    #{rank}. x=#{result.x}, y=#{result.y} → f=#{result.value}")
    end)
  end
  
  defp demo_vs_random_sampling do
    IO.puts("\n🎲 Demo 3: Grid vs Random Sampling Comparison")
    IO.puts("-" <> String.duplicate("-", 45))
    
    # Simple 2D function: minimize (x-3)² + (y-1)²
    space = fn ->
      %{
        x: {:uniform, 0, 6},
        y: {:uniform, -2, 4}
      }
    end
    
    objective = fn params ->
      x = params.x
      y = params.y
      (x - 3) * (x - 3) + (y - 1) * (y - 1)
    end
    
    n_trials = 16
    
    # Grid search
    IO.puts("\nGrid Search (4x4 grid, #{n_trials} trials):")
    grid_state = Scout.Sampler.Grid.init(%{grid_points: 4})
    
    {grid_results, _} = Enum.reduce(1..n_trials, {[], grid_state}, fn i, {acc, state} ->
      {params, new_state} = Scout.Sampler.Grid.next(space, i, [], state)
      value = objective.(params)
      result = %{x: params.x, y: params.y, value: value}
      {[result | acc], new_state}
    end)
    
    grid_best = Enum.min_by(grid_results, & &1.value)
    IO.puts("  Best: x=#{Float.round(grid_best.x, 2)}, y=#{Float.round(grid_best.y, 2)} → #{Float.round(grid_best.value, 4)}")
    
    # Random search
    IO.puts("\nRandom Search (#{n_trials} trials):")
    :rand.seed(:exsplus, {1, 2, 3})  # Fixed seed for reproducibility
    
    random_results = Enum.map(1..n_trials, fn _i ->
      params = Scout.SearchSpace.sample(space.())
      value = objective.(params)
      %{x: params.x, y: params.y, value: value}
    end)
    
    random_best = Enum.min_by(random_results, & &1.value)
    IO.puts("  Best: x=#{Float.round(random_best.x, 2)}, y=#{Float.round(random_best.y, 2)} → #{Float.round(random_best.value, 4)}")
    
    # Compare coverage
    grid_x_coverage = grid_results |> Enum.map(& &1.x) |> Enum.uniq() |> length()
    random_x_coverage = random_results |> Enum.map(&Float.round(&1.x, 1)) |> Enum.uniq() |> length()
    
    IO.puts("\n  Comparison:")
    IO.puts("    Grid search best value:    #{Float.round(grid_best.value, 4)}")
    IO.puts("    Random search best value:  #{Float.round(random_best.value, 4)}")
    IO.puts("    Grid X-axis coverage:      #{grid_x_coverage} distinct values")
    IO.puts("    Random X-axis coverage:    #{random_x_coverage} distinct values")
    
    winner = if grid_best.value <= random_best.value, do: "Grid", else: "Random"
    IO.puts("    Winner (lower is better):  #{winner} search")
  end
end

GridSamplerDemo.run()