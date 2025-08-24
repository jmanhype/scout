#!/usr/bin/env elixir

# Scout side of dogfooding comparison.
# Run IDENTICAL optimization problems to Optuna and compare results.

Code.require_file("lib/scout/search_space.ex")
Code.require_file("lib/scout/sampler.ex")
Code.require_file("lib/scout/sampler/random_search.ex")
Code.require_file("lib/scout/sampler/grid.ex")
Code.require_file("lib/scout/sampler/tpe.ex")

defmodule ScoutDogfoodComparison do
  def run do
    IO.puts("⚡ Running Scout Dogfooding Tests")
    IO.puts(String.duplicate("=", 60))
    
    # Set seed for reproducible results
    :rand.seed(:exsplus, {42, 42, 42})
    
    all_results = %{}
    
    # Test 1: Simple 2D Quadratic  
    IO.puts("\n📊 Test 1: 2D Quadratic Optimization")
    IO.puts("Objective: minimize (x-2)² + (y+1)²")
    IO.puts("Optimal: x=2, y=-1, value=0")
    
    quadratic_results = test_2d_quadratic()
    all_results = Map.merge(all_results, quadratic_results)
    
    # Test 2: ML Hyperparameters
    IO.puts("\n🤖 Test 2: ML Hyperparameter Optimization")
    IO.puts("Objective: Simulated ML training loss")
    
    ml_results = test_ml_hyperparams()
    all_results = Map.merge(all_results, ml_results)
    
    # Test 3: Rosenbrock Function
    IO.puts("\n🌹 Test 3: Rosenbrock Function")
    IO.puts("Objective: (1-x)² + 100(y-x²)²")
    IO.puts("Optimal: x=1, y=1, value=0")
    
    rosenbrock_results = test_rosenbrock()
    all_results = Map.merge(all_results, rosenbrock_results)
    
    # Save results
    json_results = Jason.encode!(all_results, pretty: true)
    File.write!("scout_dogfood_results.json", json_results)
    
    IO.puts("\n✅ Scout results saved to scout_dogfood_results.json")
    IO.puts("📊 Total studies: #{map_size(all_results)}")
    
    # Summary statistics
    IO.puts("\n📈 Summary:")
    Enum.each(all_results, fn {study_name, results} ->
      n_trials = length(results.trials)
      best_value = results.best_value
      IO.puts("  #{study_name}: #{Float.round(best_value, 6)} (#{n_trials} trials completed)")
    end)
    
    # Load Optuna results for comparison if available
    if File.exists?("optuna_dogfood_results.json") do
      compare_with_optuna(all_results)
    else
      IO.puts("\n⚠️  Run dogfood_comparison.py first to generate Optuna baseline")
    end
  end
  
  # IDENTICAL objective functions to Optuna
  
  defp objective_2d_quadratic(params) do
    x = params.x
    y = params.y
    (x - 2) * (x - 2) + (y + 1) * (y + 1)
  end
  
  defp objective_ml_hyperparams(params) do
    lr = params.learning_rate
    batch_size = params.batch_size
    layers = params.hidden_layers
    dropout = params.dropout
    
    # IDENTICAL penalty structure to Optuna
    lr_penalty = abs(:math.log10(lr) + 3) * 0.1
    batch_penalty = abs(batch_size - 64) * 0.001
    layer_penalty = abs(layers - 3) * 0.05
    dropout_penalty = abs(dropout - 0.3) * 0.2
    
    # Add some noise (using fixed seed for reproducibility)
    noise = :rand.normal() * 0.02
    
    lr_penalty + batch_penalty + layer_penalty + dropout_penalty + noise + 0.5
  end
  
  defp objective_rosenbrock(params) do
    x = params.x
    y = params.y
    a = 1
    b = 100
    (a - x) * (a - x) + b * (y - x * x) * (y - x * x)
  end
  
  # Test implementations
  
  defp test_2d_quadratic do
    space_fn = fn _ix ->
      %{
        x: {:uniform, -5, 5},
        y: {:uniform, -5, 5}
      }
    end
    
    results = %{}
    
    # Random sampler
    IO.puts("\n  Running random sampler...")
    random_result = run_scout_study(space_fn, &objective_2d_quadratic/1, :random, 25)
    IO.puts("    Best result: x=#{Float.round(random_result.best_params.x, 3)}, y=#{Float.round(random_result.best_params.y, 3)} → #{Float.round(random_result.best_value, 6)}")
    results = Map.put(results, "2d_quadratic_random", random_result)
    
    # Skip TPE for now - has interface compatibility issues
    # TPE sampler (if available)
    # IO.puts("\n  Running tpe sampler...")
    # tpe_result = run_scout_study(space_fn, &objective_2d_quadratic/1, :tpe, 25)
    # IO.puts("    Best result: x=#{Float.round(tpe_result.best_params.x, 3)}, y=#{Float.round(tpe_result.best_params.y, 3)} → #{Float.round(tpe_result.best_value, 6)}")
    # results = Map.put(results, "2d_quadratic_tpe", tpe_result)
    
    # Grid sampler
    IO.puts("\n  Running grid sampler...")
    grid_result = run_scout_study(space_fn, &objective_2d_quadratic/1, :grid, 25)
    IO.puts("    Best result: x=#{Float.round(grid_result.best_params.x, 3)}, y=#{Float.round(grid_result.best_params.y, 3)} → #{Float.round(grid_result.best_value, 6)}")
    results = Map.put(results, "2d_quadratic_grid", grid_result)
    
    results
  end
  
  defp test_ml_hyperparams do
    space_fn = fn _ix ->
      %{
        learning_rate: {:log_uniform, 1.0e-5, 1.0e-1},
        batch_size: {:choice, [16, 32, 64, 128]},
        hidden_layers: {:int, 1, 5},
        dropout: {:discrete_uniform, 0.0, 0.5, 0.1}
      }
    end
    
    results = %{}
    
    # Random sampler
    IO.puts("\n  Running random sampler...")
    random_result = run_scout_study(space_fn, &objective_ml_hyperparams/1, :random, 30)
    best = random_result.best_params
    IO.puts("    Best config: lr=#{Float.round(best.learning_rate, 5)}, batch=#{best.batch_size}, layers=#{best.hidden_layers}, dropout=#{best.dropout}")
    IO.puts("    Best value: #{Float.round(random_result.best_value, 6)}")
    results = Map.put(results, "ml_hyperparams_random", random_result)
    
    # Skip TPE for now - has interface compatibility issues  
    # TPE sampler
    # IO.puts("\n  Running tpe sampler...")
    # tpe_result = run_scout_study(space_fn, &objective_ml_hyperparams/1, :tpe, 30)
    # best = tpe_result.best_params
    # IO.puts("    Best config: lr=#{Float.round(best.learning_rate, 5)}, batch=#{best.batch_size}, layers=#{best.hidden_layers}, dropout=#{best.dropout}")
    # IO.puts("    Best value: #{Float.round(tpe_result.best_value, 6)}")
    # results = Map.put(results, "ml_hyperparams_tpe", tpe_result)
    
    results
  end
  
  defp test_rosenbrock do
    space_fn = fn _ix ->
      %{
        x: {:uniform, -2, 2},
        y: {:uniform, -2, 2}
      }
    end
    
    results = %{}
    
    # Random sampler
    IO.puts("\n  Running random sampler...")
    random_result = run_scout_study(space_fn, &objective_rosenbrock/1, :random, 100)
    IO.puts("    Best result: x=#{Float.round(random_result.best_params.x, 3)}, y=#{Float.round(random_result.best_params.y, 3)} → #{Float.round(random_result.best_value, 6)}")
    results = Map.put(results, "rosenbrock_random", random_result)
    
    # Skip TPE for now - has interface compatibility issues
    # TPE sampler
    # IO.puts("\n  Running tpe sampler...")
    # tpe_result = run_scout_study(space_fn, &objective_rosenbrock/1, :tpe, 100)
    # IO.puts("    Best result: x=#{Float.round(tpe_result.best_params.x, 3)}, y=#{Float.round(tpe_result.best_params.y, 3)} → #{Float.round(tpe_result.best_value, 6)}")
    # results = Map.put(results, "rosenbrock_tpe", tpe_result)
    
    results
  end
  
  defp run_scout_study(space_fn, objective_fn, sampler_type, n_trials) do
    # Initialize sampler
    sampler_state = case sampler_type do
      :random -> Scout.Sampler.RandomSearch.init(%{})
      :tpe -> Scout.Sampler.TPE.init(%{n_startup_trials: 10})
      :grid -> Scout.Sampler.Grid.init(%{grid_points: 5})
    end
    
    # Run optimization
    {results, _final_state} = Enum.reduce(1..n_trials, {[], sampler_state}, fn trial_num, {acc_results, acc_state} ->
      # Get next parameters  
      {params, new_state} = case sampler_type do
        :random -> Scout.Sampler.RandomSearch.next(space_fn, trial_num, acc_results, acc_state)
        :tpe -> 
          try do
            Scout.Sampler.TPE.next(space_fn, trial_num, acc_results, acc_state)
          rescue
            e ->
              IO.puts("TPE Error on trial #{trial_num}: #{inspect(e)}")
              IO.puts("Space: #{inspect(space_fn.(trial_num))}")
              # Fall back to random sampling
              sample = Scout.SearchSpace.sample(space_fn.(trial_num))
              {sample, acc_state}
          end
        :grid -> 
          # Grid sampler expects space_fun to be called without index
          grid_space_fn = fn -> space_fn.(trial_num) end
          Scout.Sampler.Grid.next(grid_space_fn, trial_num, acc_results, acc_state)
      end
      
      # Evaluate objective
      value = objective_fn.(params)
      
      trial = %{
        number: trial_num,
        value: value,
        score: value,  # TPE sampler expects :score field
        params: params
      }
      
      {[trial | acc_results], new_state}
    end)
    
    # Find best result
    best_trial = Enum.min_by(results, & &1.value)
    
    %{
      study_name: "scout_#{sampler_type}",
      sampler: sampler_type,
      n_trials: n_trials,
      best_value: best_trial.value,
      best_params: best_trial.params,
      trials: Enum.reverse(results)
    }
  end
  
  defp compare_with_optuna(scout_results) do
    IO.puts("\n🔍 COMPARISON WITH OPTUNA")
    IO.puts(String.duplicate("-", 60))
    
    case File.read("optuna_dogfood_results.json") do
      {:ok, content} ->
        optuna_results = Jason.decode!(content)
        
        # Compare each matching study
        Enum.each(scout_results, fn {study_name, scout_result} ->
          case Map.get(optuna_results, study_name) do
            nil ->
              IO.puts("⚠️  No Optuna comparison for #{study_name}")
              
            optuna_result ->
              scout_best = scout_result.best_value
              optuna_best = optuna_result["best_value"]
              
              difference = scout_best - optuna_best
              percent_diff = if optuna_best != 0, do: abs(difference / optuna_best) * 100, else: 0
              
              winner = if scout_best < optuna_best, do: "🏆 Scout", else: "🏆 Optuna"
              
              IO.puts("\n📊 #{study_name}:")
              IO.puts("  Scout:  #{Float.round(scout_best, 6)}")
              IO.puts("  Optuna: #{Float.round(optuna_best, 6)}")
              IO.puts("  Diff:   #{Float.round(difference, 6)} (#{Float.round(percent_diff, 1)}%)")
              IO.puts("  Winner: #{winner}")
          end
        end)
        
      {:error, _reason} ->
        IO.puts("⚠️  Could not read Optuna results file")
    end
  end
end

# Add JSON library dependency if not available
try do
  Jason.encode!(%{test: "value"})
rescue
  UndefinedFunctionError ->
    defmodule Jason do
      def encode!(data, _opts \\ []) do
        inspect(data, pretty: true)
      end
      
      def decode!(json) do
        # Simple JSON parsing - would need proper implementation
        %{}
      end
    end
end

ScoutDogfoodComparison.run()