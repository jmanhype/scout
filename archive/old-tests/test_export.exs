# Test export functionality
IO.puts("\n=== Testing Scout Export Capabilities ===\n")

# First, create and run a small study
IO.puts("1. Creating a test study with some trials...")

result = Scout.Easy.optimize(
  fn params -> 
    # Rosenbrock function
    x = params.x
    y = params.y
    :math.pow(1 - x, 2) + 100 * :math.pow(y - x * x, 2)
  end,
  %{
    x: {:uniform, -2, 2},
    y: {:uniform, -2, 2}
  },
  n_trials: 10,
  study_id: "export-test-study"
)

IO.puts("   Study completed: #{result.n_trials} trials")
IO.puts("   Best value: #{result.best_value}")

# Test JSON export
IO.puts("\n2. Testing JSON export...")

case Scout.Export.to_json("export-test-study", pretty: true) do
  {:ok, json} ->
    # Show first 500 chars of JSON
    preview = String.slice(json, 0, 500)
    IO.puts("   JSON export successful!")
    IO.puts("   Preview: #{preview}...")
    
    # Save to file
    case Scout.Export.to_file("export-test-study", "test_results.json") do
      :ok -> IO.puts("   ✓ Saved to test_results.json")
      {:error, reason} -> IO.puts("   ✗ Failed to save: #{inspect(reason)}")
    end
    
  {:error, reason} ->
    IO.puts("   ✗ JSON export failed: #{inspect(reason)}")
end

# Test CSV export
IO.puts("\n3. Testing CSV export...")

case Scout.Export.to_csv("export-test-study") do
  {:ok, csv} ->
    # Show first few lines
    lines = String.split(csv, "\n") |> Enum.take(5)
    IO.puts("   CSV export successful!")
    IO.puts("   First 5 lines:")
    Enum.each(lines, fn line -> IO.puts("   #{line}") end)
    
    # Save to file
    case Scout.Export.to_file("export-test-study", "test_results.csv", format: :csv) do
      :ok -> IO.puts("   ✓ Saved to test_results.csv")
      {:error, reason} -> IO.puts("   ✗ Failed to save: #{inspect(reason)}")
    end
    
  {:error, reason} ->
    IO.puts("   ✗ CSV export failed: #{inspect(reason)}")
end

# Test study statistics
IO.puts("\n4. Testing study statistics...")

case Scout.Export.study_stats("export-test-study") do
  {:ok, stats} ->
    IO.puts("   Study statistics:")
    IO.puts("   - Goal: #{stats.goal}")
    IO.puts("   - Total trials: #{stats.n_trials}")
    IO.puts("   - Completed trials: #{stats.n_completed}")
    IO.puts("   - Pruned trials: #{stats.n_pruned}")
    IO.puts("   - Best value: #{stats.best_value}")
    IO.puts("   - Mean value: #{stats.mean_value}")
    IO.puts("   - Std deviation: #{stats.std_value}")
    IO.puts("   - Min value: #{stats.min_value}")
    IO.puts("   - Max value: #{stats.max_value}")
    
  {:error, reason} ->
    IO.puts("   ✗ Stats failed: #{inspect(reason)}")
end

IO.puts("\n✅ Export functionality test complete!")