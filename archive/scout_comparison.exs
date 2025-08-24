#!/usr/bin/env elixir

# SCOUT COMPARISON TEST - Direct Optuna Parity Proof

defmodule ScoutComparison do
  @moduledoc """
  Identical tests to optuna_baseline.py for direct parity comparison
  """
  
  # Identical to Optuna ml_hyperparameter_objective
  def ml_hyperparameter_objective(params) do
    learning_rate = params[:learning_rate] || 0.1
    max_depth = params[:max_depth] || 6
    n_estimators = params[:n_estimators] || 100
    subsample = params[:subsample] || 1.0
    colsample_bytree = params[:colsample_bytree] || 1.0
    
    # Identical simulation to Optuna (optimal around lr=0.1, depth=6, n_est=100)
    lr_score = -abs(:math.log10(learning_rate) + 1.0)
    depth_score = -abs(max_depth - 6) * 0.05
    n_est_score = -abs(n_estimators - 100) * 0.001
    subsample_score = -abs(subsample - 0.8) * 0.1
    colsample_score = -abs(colsample_bytree - 0.8) * 0.1
    
    accuracy = 0.8 + lr_score + depth_score + n_est_score + subsample_score + colsample_score
    {:ok, max(0.0, min(1.0, accuracy))}
  end
  
  def ml_search_space(_) do
    %{
      learning_rate: {:log_uniform, 0.001, 0.3},
      max_depth: {:int, 3, 10},
      n_estimators: {:int, 50, 300},
      subsample: {:uniform, 0.5, 1.0},
      colsample_bytree: {:uniform, 0.5, 1.0}
    }
  end
  
  # Identical to Optuna multi_objective_function
  def multi_objective_function(params) do
    n_estimators = params[:n_estimators] || 100
    max_depth = params[:max_depth] || 6
    
    complexity = n_estimators * max_depth / 100.0
    accuracy = 0.7 + 0.3 * (1 - :math.exp(-complexity))
    inference_time = 0.1 + complexity * 0.5
    
    {:ok, %{accuracy: accuracy, inference_time: inference_time}}
  end
  
  def multi_objective_search_space(_) do
    %{
      n_estimators: {:int, 10, 200},
      max_depth: {:int, 2, 20}
    }
  end
  
  # Identical to Optuna conditional_optimizer_objective
  def conditional_optimizer_objective(params) do
    optimizer = params[:optimizer] || "adam"
    
    score = case optimizer do
      "adam" ->
        lr = params[:adam_lr] || 0.001
        beta1 = params[:adam_beta1] || 0.9
        beta2 = params[:adam_beta2] || 0.999
        
        -abs(:math.log10(lr) + 3.0) * 0.5 +
        -abs(beta1 - 0.9) * 2.0 +
        -abs(beta2 - 0.999) * 10.0
        
      "sgd" ->
        lr = params[:sgd_lr] || 0.01
        momentum = params[:sgd_momentum] || 0.9
        
        -abs(:math.log10(lr) + 2.0) * 0.5 +
        -abs(momentum - 0.9) * 2.0
        
      "rmsprop" ->
        lr = params[:rmsprop_lr] || 0.001
        decay = params[:rmsprop_decay] || 0.9
        
        -abs(:math.log10(lr) + 3.0) * 0.5 +
        -abs(decay - 0.9) * 2.0
        
      _ -> -10.0
    end
    
    {:ok, score + 1.0}  # Shift to positive
  end
  
  def conditional_search_space(_) do
    %{
      optimizer: {:choice, ["adam", "sgd", "rmsprop"]},
      
      # Adam-specific parameters  
      adam_lr: Scout.ConditionalSpace.conditional(
        fn params -> params.optimizer == "adam" end,
        {:log_uniform, 0.0001, 0.01}
      ),
      adam_beta1: Scout.ConditionalSpace.conditional(
        fn params -> params.optimizer == "adam" end,
        {:uniform, 0.8, 0.95}
      ),
      adam_beta2: Scout.ConditionalSpace.conditional(
        fn params -> params.optimizer == "adam" end,
        {:uniform, 0.99, 0.9999}
      ),
      
      # SGD-specific parameters
      sgd_lr: Scout.ConditionalSpace.conditional(
        fn params -> params.optimizer == "sgd" end,
        {:log_uniform, 0.001, 0.1}
      ),
      sgd_momentum: Scout.ConditionalSpace.conditional(
        fn params -> params.optimizer == "sgd" end,
        {:uniform, 0.8, 0.95}
      ),
      
      # RMSprop-specific parameters
      rmsprop_lr: Scout.ConditionalSpace.conditional(
        fn params -> params.optimizer == "rmsprop" end,
        {:log_uniform, 0.0001, 0.01}
      ),
      rmsprop_decay: Scout.ConditionalSpace.conditional(
        fn params -> params.optimizer == "rmsprop" end,
        {:uniform, 0.8, 0.95}
      )
    }
  end
  
  # Identical to Optuna rastrigin_objective  
  def rastrigin_objective(params) do
    x = params[:x] || 0.0
    y = params[:y] || 0.0
    
    # Rastrigin function (minimize)
    result = 20 + x*x - 10*:math.cos(2*:math.pi*x) + y*y - 10*:math.cos(2*:math.pi*y)
    {:ok, result}
  end
  
  def rastrigin_search_space(_) do
    %{
      x: {:uniform, -5.12, 5.12},
      y: {:uniform, -5.12, 5.12}
    }
  end
  
  def run_test(test_name, objective_func, search_space_func, sampler_module, sampler_opts, n_trials) do
    IO.puts("\n🔬 Running #{test_name}")
    IO.puts("─" <> String.duplicate("─", 59))
    
    start_time = System.monotonic_time(:millisecond)
    
    state = sampler_module.init(sampler_opts)
    history = []
    convergence_data = []
    
    {best_value, best_params, final_history} = 
      Enum.reduce(1..n_trials, {nil, %{}, []}, fn i, {best_so_far, best_p, hist} ->
        {params, new_state} = sampler_module.next(search_space_func, i, hist, state)
        {:ok, score} = objective_func.(params)
        
        # Handle different score types (single value, multi-objective map)
        {normalized_score, raw_score} = case score do
          %{} = multi_scores -> 
            # Multi-objective: use negative accuracy as primary metric for maximization
            {-multi_scores.accuracy, multi_scores}
          single_score -> 
            {single_score, single_score}
        end
        
        trial = %Scout.Trial{
          id: "trial-#{i}",
          study_id: "scout-comparison",
          params: params,
          bracket: 0,
          score: raw_score,
          status: :succeeded
        }
        
        new_history = hist ++ [trial]
        
        # Track best (for maximize: higher is better, for minimize: lower is better)
        new_best_value = case sampler_opts[:goal] do
          :maximize -> 
            if best_so_far == nil or normalized_score > best_so_far,
              do: normalized_score, else: best_so_far
          :minimize -> 
            if best_so_far == nil or normalized_score < best_so_far,
              do: normalized_score, else: best_so_far
        end
        
        new_best_params = if new_best_value == normalized_score, do: params, else: best_p
        
        convergence_data = convergence_data ++ [{i, raw_score, new_best_value, params}]
        
        {new_best_value, new_best_params, new_history}
      end)
    
    end_time = System.monotonic_time(:millisecond)
    execution_time = (end_time - start_time) / 1000.0
    
    result = %{
      test_name: test_name,
      n_trials: n_trials,
      execution_time: execution_time,
      best_value: best_value,
      best_params: best_params,
      n_completed_trials: length(final_history),
      convergence_data: convergence_data
    }
    
    # Print summary
    IO.puts("Best value: #{Float.round(best_value, 6)}")
    IO.puts("Best params: #{inspect(best_params)}")
    IO.puts("Execution time: #{Float.round(execution_time, 2)}s")
    IO.puts("Completed trials: #{result.n_completed_trials}/#{n_trials}")
    
    result
  end
  
  def run_all_tests() do
    IO.puts("""
    ╔═══════════════════════════════════════════════════════════════════╗
    ║                      SCOUT COMPARISON TESTS                       ║
    ║                   (Direct Optuna Parity Test)                     ║
    ╚═══════════════════════════════════════════════════════════════════╝
    """)
    
    results = %{}
    
    # Test 1: Basic TPE on ML hyperparameters (identical to Optuna)
    basic_tpe_opts = %{
      min_obs: 10,  # n_startup_trials in Optuna
      gamma: 0.25,
      goal: :maximize
    }
    
    result1 = run_test(
      "basic_tpe_ml",
      &ml_hyperparameter_objective/1,
      &ml_search_space/1,
      Scout.Sampler.TPE,
      basic_tpe_opts,
      30
    )
    
    results = Map.put(results, "basic_tpe_ml", result1)
    
    # Test 2: Conditional search spaces (identical to Optuna conditional spaces)
    if Code.ensure_loaded?(Scout.Sampler.ConditionalTPE) do
      conditional_opts = %{
        min_obs: 10,
        gamma: 0.25,
        goal: :maximize,
        group: true  # Like Optuna's group=True
      }
      
      result2 = run_test(
        "conditional_spaces",
        &conditional_optimizer_objective/1,
        &conditional_search_space/1,
        Scout.Sampler.ConditionalTPE,
        conditional_opts,
        25
      )
      
      results = Map.put(results, "conditional_spaces", result2)
    else
      IO.puts("\n⚠️ ConditionalTPE not available")
    end
    
    # Test 3: Multi-objective optimization
    if Code.ensure_loaded?(Scout.Sampler.MOTPE) do
      IO.puts("\n🔬 Running multi_objective")
      IO.puts("─" <> String.duplicate("─", 59))
      
      # For multi-objective, we'll simulate what Optuna does
      motpe_opts = %{
        min_obs: 10,
        gamma: 0.25,
        goal: :minimize,  # Multi-objective typically minimizes
        n_objectives: 2
      }
      
      state = Scout.Sampler.MOTPE.init(motpe_opts)
      history = []
      pareto_front = []
      
      start_time = System.monotonic_time(:millisecond)
      
      for i <- 1..20 do
        {params, _} = Scout.Sampler.MOTPE.next(&multi_objective_search_space/1, i, history, state)
        {:ok, scores} = multi_objective_function.(params)
        
        # Convert to minimization (negate accuracy, keep inference_time positive)
        objective_scores = %{accuracy: -scores.accuracy, inference_time: scores.inference_time}
        
        trial = %Scout.Trial{
          id: "trial-#{i}",
          study_id: "motpe-comparison",
          params: params,
          bracket: 0,
          score: objective_scores,
          status: :succeeded
        }
        
        history = history ++ [trial]
        
        # Check Pareto dominance (minimize both objectives)
        is_dominated = Enum.any?(pareto_front, fn t ->
          t.score.accuracy <= objective_scores.accuracy and 
          t.score.inference_time <= objective_scores.inference_time and
          (t.score.accuracy < objective_scores.accuracy or t.score.inference_time < objective_scores.inference_time)
        end)
        
        if not is_dominated do
          # Remove dominated solutions
          pareto_front = Enum.filter(pareto_front, fn t ->
            not (objective_scores.accuracy <= t.score.accuracy and 
                 objective_scores.inference_time <= t.score.inference_time and
                 (objective_scores.accuracy < t.score.accuracy or objective_scores.inference_time < t.score.inference_time))
          end)
          pareto_front = pareto_front ++ [trial]
        end
      end
      
      end_time = System.monotonic_time(:millisecond)
      execution_time = (end_time - start_time) / 1000.0
      
      IO.puts("Pareto front size: #{length(pareto_front)}")
      IO.puts("Sample solutions:")
      for {trial, idx} <- Enum.with_index(Enum.take(pareto_front, 3)) do
        acc = Float.round(-trial.score.accuracy, 3)
        time = Float.round(trial.score.inference_time, 3)
        IO.puts("  #{idx+1}: acc=#{acc}, time=#{time}")
      end
      
      result3 = %{
        test_name: "multi_objective",
        n_trials: 20,
        execution_time: execution_time,
        pareto_front_size: length(pareto_front),
        pareto_front: pareto_front
      }
      
      results = Map.put(results, "multi_objective", result3)
    else
      IO.puts("\n⚠️ MOTPE not available")
    end
    
    # Test 4: Rastrigin benchmark (identical to Optuna)
    rastrigin_opts = %{
      min_obs: 10,
      gamma: 0.25,
      goal: :minimize  # Minimize Rastrigin function
    }
    
    result4 = run_test(
      "rastrigin_benchmark",
      &rastrigin_objective/1,
      &rastrigin_search_space/1,
      Scout.Sampler.TPE,
      rastrigin_opts,
      50
    )
    
    results = Map.put(results, "rastrigin_benchmark", result4)
    
    # Test 5: Multivariate TPE (identical to Optuna multivariate=True)
    if Code.ensure_loaded?(Scout.Sampler.MultivarTPE) do
      multivar_opts = %{
        min_obs: 10,
        gamma: 0.25,
        goal: :maximize,
        correlation_threshold: 0.3  # Enable correlation modeling
      }
      
      result5 = run_test(
        "multivariate_tpe",
        &ml_hyperparameter_objective/1,
        &ml_search_space/1,
        Scout.Sampler.MultivarTPE,
        multivar_opts,
        30
      )
      
      results = Map.put(results, "multivariate_tpe", result5)
    else
      IO.puts("\n⚠️ MultivarTPE not available")
    end
    
    results
  end
  
  def save_results(results, filename \\ "scout_comparison_results.json") do
    # Convert results to JSON-serializable format
    json_results = Map.new(results, fn {key, result} ->
      case result do
        %{pareto_front: pareto_front} = multi_obj ->
          # Handle multi-objective results
          json_pareto = Enum.map(pareto_front, fn trial ->
            %{
              params: trial.params,
              accuracy: -trial.score.accuracy,  # Convert back to original accuracy
              inference_time: trial.score.inference_time
            }
          end)
          {key, Map.put(multi_obj, :pareto_front, json_pareto)}
          
        regular_result ->
          # Handle single-objective results
          json_convergence = Enum.map(regular_result.convergence_data, fn {trial, score, best, params} ->
            %{trial: trial, value: score, best_so_far: best, params: params}
          end)
          {key, Map.put(regular_result, :convergence_data, json_convergence)}
      end
    end)
    
    case Jason.encode(json_results, pretty: true) do
      {:ok, json_string} ->
        File.write!(filename, json_string)
        IO.puts("\n💾 Results saved to #{filename}")
      {:error, reason} ->
        IO.puts("\n❌ Failed to save results: #{inspect(reason)}")
    end
  end
  
  def print_summary(results) do
    IO.puts("\n")
    IO.puts("""
    ╔═══════════════════════════════════════════════════════════════════╗
    ║                        SCOUT COMPARISON SUMMARY                   ║
    ╚═══════════════════════════════════════════════════════════════════╝
    """)
    
    for {test_name, result} <- results do
      case result do
        %{pareto_front_size: size} ->
          IO.puts("📊 #{String.pad_trailing(test_name, 20)} | Pareto front: #{size} solutions")
        %{best_value: best} ->
          IO.puts("📊 #{String.pad_trailing(test_name, 20)} | Best: #{Float.round(best, 6)}")
      end
    end
  end
  
  def compare_with_optuna() do
    IO.puts("\n")
    IO.puts("""
    ╔═══════════════════════════════════════════════════════════════════╗
    ║                    SCOUT vs OPTUNA COMPARISON                     ║
    ╚═══════════════════════════════════════════════════════════════════╝
    """)
    
    # Load Optuna results if available
    case File.read("optuna_baseline_results.json") do
      {:ok, optuna_content} ->
        case Jason.decode(optuna_content) do
          {:ok, optuna_results} ->
            case File.read("scout_comparison_results.json") do
              {:ok, scout_content} ->
                case Jason.decode(scout_content) do
                  {:ok, scout_results} ->
                    print_comparison_table(optuna_results, scout_results)
                  {:error, _} ->
                    IO.puts("❌ Failed to parse Scout results")
                end
              {:error, _} ->
                IO.puts("⚠️ Scout results not found - run tests first")
            end
          {:error, _} ->
            IO.puts("❌ Failed to parse Optuna results")
        end
      {:error, _} ->
        IO.puts("⚠️ Optuna baseline results not found - run optuna_baseline.py first")
    end
  end
  
  defp print_comparison_table(optuna_results, scout_results) do
    IO.puts("┌─────────────────────┬──────────────┬──────────────┬──────────────┐")
    IO.puts("│ Test                │ Optuna       │ Scout        │ Difference   │")
    IO.puts("├─────────────────────┼──────────────┼──────────────┼──────────────┤")
    
    for {test_name, optuna_result} <- optuna_results do
      case Map.get(scout_results, test_name) do
        nil ->
          IO.puts("│ #{String.pad_trailing(test_name, 19)} │ #{String.pad_trailing("#{Float.round(optuna_result["best_value"], 6)}", 12)} │ Missing      │ N/A          │")
          
        scout_result ->
          case {optuna_result["best_value"], scout_result["best_value"]} do
            {optuna_best, scout_best} when is_number(optuna_best) and is_number(scout_best) ->
              diff = abs(scout_best - optuna_best)
              diff_pct = if optuna_best != 0, do: (diff / abs(optuna_best)) * 100, else: 0
              
              optuna_str = String.pad_trailing("#{Float.round(optuna_best, 6)}", 12)
              scout_str = String.pad_trailing("#{Float.round(scout_best, 6)}", 12)
              diff_str = String.pad_trailing("#{Float.round(diff_pct, 2)}%", 12)
              
              IO.puts("│ #{String.pad_trailing(test_name, 19)} │ #{optuna_str} │ #{scout_str} │ #{diff_str} │")
            _ ->
              IO.puts("│ #{String.pad_trailing(test_name, 19)} │ Multi-obj    │ Multi-obj    │ See details  │")
          end
      end
    end
    
    IO.puts("└─────────────────────┴──────────────┴──────────────┴──────────────┘")
    IO.puts("")
    IO.puts("🎯 PARITY ANALYSIS:")
    IO.puts("- Differences < 5% indicate excellent parity")  
    IO.puts("- Differences 5-15% indicate good parity")
    IO.puts("- Differences > 15% may indicate implementation gaps")
  end
end

# Run all tests
results = ScoutComparison.run_all_tests()
ScoutComparison.save_results(results)
ScoutComparison.print_summary(results)
ScoutComparison.compare_with_optuna()

IO.puts("\n🎯 Next: Compare results to identify any Scout vs Optuna gaps!")