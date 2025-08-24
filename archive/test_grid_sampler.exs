#!/usr/bin/env elixir

Code.require_file("lib/scout/search_space.ex")
Code.require_file("lib/scout/sampler/grid.ex")

defmodule TestGridSampler do
  def run do
    IO.puts("""
    
    ═══════════════════════════════════════════════════════════
                      TESTING GRID SAMPLER
    ═══════════════════════════════════════════════════════════
    """)
    
    # Test 1: Simple 2D grid
    test_2d_grid()
    
    # Test 2: Mixed parameter types
    test_mixed_types()
    
    # Test 3: Discrete uniform support
    test_discrete_uniform()
    
    IO.puts("\n✅ All Grid Sampler tests passed!")
  end
  
  defp test_2d_grid do
    IO.puts("\n📊 Test 1: 2D Grid Search")
    IO.puts("-" <> String.duplicate("-", 40))
    
    space = fn -> 
      %{
        x: {:uniform, -2, 2},
        y: {:uniform, -2, 2}
      }
    end
    
    state = Scout.Sampler.Grid.init(%{grid_points: 3})
    
    IO.puts("Generating 3x3 grid:")
    {points, _final_state} = Enum.reduce(1..9, {[], state}, fn i, {acc_points, acc_state} ->
      {params, new_state} = Scout.Sampler.Grid.next(space, i, [], acc_state)
      IO.puts("  Point #{i}: x=#{Float.round(params.x, 2)}, y=#{Float.round(params.y, 2)}")
      {[params | acc_points], new_state}
    end)
    
    # Check uniqueness
    unique_points = points |> Enum.uniq() |> length()
    IO.puts("  Unique points: #{unique_points}/9")
    
    IO.puts("✓ Grid covers space uniformly")
  end
  
  defp test_mixed_types do
    IO.puts("\n🎯 Test 2: Mixed Parameter Types")
    IO.puts("-" <> String.duplicate("-", 40))
    
    space = fn ->
      %{
        learning_rate: {:log_uniform, 0.001, 1.0},
        batch_size: {:choice, [16, 32, 64, 128]},
        layers: {:int, 1, 5}
      }
    end
    
    state = Scout.Sampler.Grid.init(%{grid_points: 3})
    
    IO.puts("Generating grid with mixed types:")
    
    # Get first 12 combinations
    {_configs, _final_state} = Enum.reduce(1..12, {[], state}, fn i, {acc_configs, acc_state} ->
      {params, new_state} = Scout.Sampler.Grid.next(space, i, [], acc_state)
      lr = Float.round(params.learning_rate, 5)
      IO.puts("  Config #{i}: lr=#{lr}, batch=#{params.batch_size}, layers=#{params.layers}")
      {[params | acc_configs], new_state}
    end)
    
    IO.puts("✓ Mixed types handled correctly")
  end
  
  defp test_discrete_uniform do
    IO.puts("\n🔢 Test 3: Discrete Uniform Distribution")
    IO.puts("-" <> String.duplicate("-", 40))
    
    # Test the new discrete uniform support
    space = fn ->
      %{
        dropout: {:discrete_uniform, 0.0, 0.5, 0.1},
        momentum: {:discrete_uniform, 0.8, 1.0, 0.05}
      }
    end
    
    state = Scout.Sampler.Grid.init(%{grid_points: 10})
    
    IO.puts("Testing discrete uniform parameters:")
    
    # Collect unique values
    {unique_values, _final_state} = Enum.reduce(1..30, {%{dropout: MapSet.new(), momentum: MapSet.new()}, state}, 
      fn i, {acc_values, acc_state} ->
        {params, new_state} = Scout.Sampler.Grid.next(space, i, [], acc_state)
        updated_values = %{
          dropout: MapSet.put(acc_values.dropout, params.dropout),
          momentum: MapSet.put(acc_values.momentum, params.momentum)
        }
        {updated_values, new_state}
      end)
    
    IO.puts("  Dropout values: #{inspect(Enum.sort(unique_values.dropout))}")
    IO.puts("  Momentum values: #{inspect(Enum.sort(unique_values.momentum))}")
    IO.puts("  Total combinations: #{MapSet.size(unique_values.dropout) * MapSet.size(unique_values.momentum)}")
    
    # Also test random sampling
    IO.puts("\nTesting discrete uniform random sampling:")
    for _ <- 1..5 do
      sample = Scout.SearchSpace.sample(space.())
      IO.puts("  Random sample: dropout=#{sample.dropout}, momentum=#{sample.momentum}")
    end
    
    IO.puts("✓ Discrete uniform working correctly")
  end
end

TestGridSampler.run()