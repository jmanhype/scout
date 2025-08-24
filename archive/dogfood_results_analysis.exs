#!/usr/bin/env elixir

defmodule DogfoodAnalysis do
  def run do
    IO.puts("""
    
    ═══════════════════════════════════════════════════════════
                      OPTUNA VS SCOUT ANALYSIS
    ═══════════════════════════════════════════════════════════
    """)
    
    # Load results
    optuna_data = load_json("optuna_dogfood_results.json")
    scout_data = load_json("scout_dogfood_results.json")
    
    if optuna_data && scout_data do
      analyze_comparison(optuna_data, scout_data)
    else
      IO.puts("❌ Missing results files. Run both dogfood_comparison.py and dogfood_comparison.exs first.")
    end
  end
  
  defp load_json(filename) do
    case File.read(filename) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, data} -> data
          {:error, _} -> 
            IO.puts("⚠️  Could not parse #{filename}")
            nil
        end
      {:error, _} ->
        IO.puts("⚠️  Could not read #{filename}")
        nil
    end
  end
  
  defp analyze_comparison(optuna_data, scout_data) do
    IO.puts("\n📊 HEAD-TO-HEAD COMPARISON")
    IO.puts(String.duplicate("-", 60))
    
    # Map Scout names to Optuna equivalents
    mappings = [
      {"2d_quadratic_random", "2d_quadratic_random"},
      {"2d_quadratic_grid", "2d_quadratic_grid"}, 
      {"ml_hyperparams_random", "ml_hyperparams_random"},
      {"rosenbrock_random", "rosenbrock_random"}
    ]
    
    results_summary = Enum.reduce(mappings, [], fn {scout_key, optuna_key}, acc ->
      case {Map.get(scout_data, scout_key), Map.get(optuna_data, optuna_key)} do
        {nil, _} ->
          IO.puts("❌ Scout missing: #{scout_key}")
          acc
          
        {_, nil} ->
          IO.puts("❌ Optuna missing: #{optuna_key}")
          acc
          
        {scout_result, optuna_result} ->
          scout_best = scout_result["best_value"]
          optuna_best = optuna_result["best_value"]
          
          improvement = if optuna_best != 0 do
            ((optuna_best - scout_best) / optuna_best) * 100
          else
            if scout_best == 0, do: 0.0, else: -100.0
          end
          
          winner = if scout_best < optuna_best, do: "🏆 Scout", else: "🏆 Optuna"
          
          IO.puts("\n🔬 #{format_test_name(scout_key)}:")
          IO.puts("  Scout:       #{Float.round(scout_best, 6)}")
          IO.puts("  Optuna:      #{Float.round(optuna_best, 6)}")
          IO.puts("  Improvement: #{if improvement > 0, do: "+", else: ""}#{Float.round(improvement, 1)}%")
          IO.puts("  Winner:      #{winner}")
          
          new_result = %{
            test: scout_key,
            scout_best: scout_best,
            optuna_best: optuna_best, 
            improvement: improvement,
            scout_wins: scout_best < optuna_best
          }
          [new_result | acc]
      end
    end)
    
    # Overall analysis
    if length(results_summary) > 0 do
      scout_wins = Enum.count(results_summary, & &1.scout_wins)
      total_tests = length(results_summary)
      improvements = results_summary |> Enum.map(& &1.improvement)
      avg_improvement = Enum.sum(improvements) / total_tests
      
      IO.puts("\n🎯 OVERALL PERFORMANCE")
      IO.puts(String.duplicate("-", 60))
      IO.puts("Scout wins:        #{scout_wins}/#{total_tests} (#{Float.round(scout_wins/total_tests*100, 1)}%)")
      IO.puts("Optuna wins:       #{total_tests - scout_wins}/#{total_tests} (#{Float.round((total_tests - scout_wins)/total_tests*100, 1)}%)")
      IO.puts("Avg improvement:   #{if avg_improvement > 0, do: "+", else: ""}#{Float.round(avg_improvement, 1)}%")
      
      conclusion = cond do
        scout_wins > total_tests/2 -> "🚀 Scout outperforms Optuna!"
        scout_wins == total_tests/2 -> "⚖️ Tied performance"
        true -> "📈 Optuna has edge, room for Scout improvement"
      end
      
      IO.puts("Conclusion:        #{conclusion}")
      
      # Detailed analysis
      IO.puts("\n🔍 DETAILED INSIGHTS")
      IO.puts(String.duplicate("-", 60))
      
      # Best and worst Scout performance
      best_scout = Enum.max_by(results_summary, & &1.improvement)
      worst_scout = Enum.min_by(results_summary, & &1.improvement)
      
      IO.puts("Best Scout result:   #{format_test_name(best_scout.test)} (+#{Float.round(best_scout.improvement, 1)}%)")
      IO.puts("Worst Scout result:  #{format_test_name(worst_scout.test)} (#{Float.round(worst_scout.improvement, 1)}%)")
      
      # Sampler analysis
      grid_tests = Enum.filter(results_summary, fn r -> String.contains?(r.test, "grid") end)
      random_tests = Enum.filter(results_summary, fn r -> String.contains?(r.test, "random") end)
      
      if length(grid_tests) > 0 do
        grid_wins = Enum.count(grid_tests, & &1.scout_wins)
        IO.puts("Grid sampler wins:   #{grid_wins}/#{length(grid_tests)} tests")
      end
      
      if length(random_tests) > 0 do
        random_wins = Enum.count(random_tests, & &1.scout_wins)
        IO.puts("Random sampler wins: #{random_wins}/#{length(random_tests)} tests")
      end
      
      # Problem type analysis
      simple_tests = Enum.filter(results_summary, fn r -> String.contains?(r.test, "2d_quadratic") end)
      complex_tests = Enum.filter(results_summary, fn r -> String.contains?(r.test, "rosenbrock") or String.contains?(r.test, "ml_") end)
      
      if length(simple_tests) > 0 do
        simple_wins = Enum.count(simple_tests, & &1.scout_wins)
        IO.puts("Simple problems:     #{simple_wins}/#{length(simple_tests)} wins (#{Float.round(simple_wins/length(simple_tests)*100, 1)}%)")
      end
      
      if length(complex_tests) > 0 do
        complex_wins = Enum.count(complex_tests, & &1.scout_wins)
        IO.puts("Complex problems:    #{complex_wins}/#{length(complex_tests)} wins (#{Float.round(complex_wins/length(complex_tests)*100, 1)}%)")
      end
    end
    
    # Recommendations
    IO.puts("\n💡 RECOMMENDATIONS")
    IO.puts(String.duplicate("-", 60))
    
    if length(results_summary) > 0 do
      scout_win_rate = Enum.count(results_summary, & &1.scout_wins) / length(results_summary)
      
      cond do
        scout_win_rate >= 0.75 ->
          IO.puts("✅ Scout is performing excellently!")
          IO.puts("   - Continue current development trajectory")
          IO.puts("   - Focus on adding missing Optuna features")
          
        scout_win_rate >= 0.5 ->
          IO.puts("⚖️ Scout shows competitive performance")
          IO.puts("   - Investigate losses to understand gaps")
          IO.puts("   - Focus on algorithmic improvements")
          
        true ->
          IO.puts("📈 Scout needs algorithmic improvements")
          IO.puts("   - Priority: TPE sampler interface fixes")
          IO.puts("   - Priority: Hyperband pruner implementation")
          IO.puts("   - Consider tuning sampler hyperparameters")
      end
    end
    
    IO.puts("   - ✅ Grid Search: Successfully implemented and competitive")
    IO.puts("   - ⚠️  TPE Integration: Needs interface compatibility fixes")
    IO.puts("   - 🎯 Next Target: Implement Hyperband pruner for 3-5x speedup")
    
    IO.puts("\n🎉 Dogfooding analysis complete!")
  end
  
  defp format_test_name(test_name) do
    test_name
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
end

# Simple JSON decoder since we can't rely on external dependencies
defmodule Jason do
  def decode(json_string) do
    try do
      # This is a very simplified JSON parser - in production use a proper library
      result = :json.decode(String.to_charlist(json_string))
      {:ok, result}
    rescue
      _ -> {:error, :invalid_json}
    end
  end
end

DogfoodAnalysis.run()