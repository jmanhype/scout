#!/usr/bin/env elixir

# Test Scout's Phoenix LiveView Dashboard with Real Optimization
# This will create studies that we can monitor in the browser

defmodule DashboardTestStudy do
  @moduledoc """
  Study module for testing Scout's dashboard with durable execution
  """
  
  # Complex ML search space for visual interest
  def search_space(_ix) do
    %{
      # Neural architecture
      n_layers: {:int, 2, 8},
      layer_1_size: {:int, 32, 512},
      layer_2_size: {:int, 16, 256},
      dropout_1: {:uniform, 0.1, 0.6},
      dropout_2: {:uniform, 0.0, 0.4},
      
      # Training config
      learning_rate: {:log_uniform, 1.0e-5, 1.0e-1},
      batch_size: {:int, 8, 128},
      weight_decay: {:log_uniform, 1.0e-6, 1.0e-1},
      
      # Optimizer choice
      optimizer: {:choice, ["adam", "sgd", "rmsprop", "adagrad"]},
      lr_scheduler: {:choice, ["cosine", "step", "exponential", nil]},
      
      # Activation functions
      activation_1: {:choice, ["relu", "tanh", "elu", "gelu", "swish"]},
      activation_2: {:choice, ["relu", "tanh", "elu", "sigmoid"]}
    }
  end
  
  # Iterative objective with progressive evaluation for Hyperband
  def objective(params, report_fn) do
    # Simulate complex ML training with realistic learning curves
    simulate_deep_learning_training(params, report_fn)
  end
  
  defp simulate_deep_learning_training(params, report_fn) do
    # Calculate potential based on hyperparameters
    base_performance = 0.75
    
    # Architecture impact (non-linear interactions)
    arch_score = calculate_architecture_score(params)
    
    # Training configuration impact  
    training_score = calculate_training_score(params)
    
    # Optimizer and scheduler impact
    opt_score = calculate_optimizer_score(params)
    
    # Final potential accuracy
    potential = base_performance + arch_score + training_score + opt_score
    potential = max(0.60, min(0.98, potential))
    
    # Learning rate determines convergence characteristics
    convergence_rate = case params.learning_rate do
      lr when lr > 0.01 -> 0.5   # Fast but unstable
      lr when lr > 0.001 -> 0.8  # Good balance
      lr when lr > 0.0001 -> 0.9 # Slow but steady
      _ -> 0.95                  # Very slow
    end
    
    # Simulate training over epochs with realistic curves
    max_epochs = 20
    noise_level = 0.02
    
    Enum.reduce_while(1..max_epochs, 0.0, fn epoch, prev_acc ->
      # Calculate progress (sigmoid-like curve)
      progress = :math.pow(epoch / max_epochs, convergence_rate)
      
      # Add some realistic noise and fluctuations
      noise = (:rand.uniform() - 0.5) * noise_level
      epoch_fluctuation = :math.sin(epoch * 0.3) * 0.01
      
      current_acc = potential * progress + noise + epoch_fluctuation
      current_acc = max(0.50, min(0.98, current_acc))
      
      # Small chance of overfitting in later epochs
      if epoch > 15 and :rand.uniform() < 0.1 do
        current_acc = current_acc * 0.98
      end
      
      # Report for pruning consideration
      case report_fn.(current_acc, epoch - 1) do  # 0-indexed rung
        :prune -> 
          {:halt, current_acc}
        :continue -> 
          if epoch == max_epochs do
            {:halt, current_acc}
          else
            {:cont, current_acc}
          end
      end
    end)
  end
  
  defp calculate_architecture_score(params) do
    # Complex architecture scoring
    layer_balance = if params.layer_1_size >= 2 * params.layer_2_size, do: 0.02, else: -0.01
    
    depth_bonus = case params.n_layers do
      n when n >= 4 and n <= 6 -> 0.05
      n when n >= 3 -> 0.03
      _ -> -0.02
    end
    
    size_bonus = if params.layer_1_size >= 128 and params.layer_1_size <= 256, do: 0.03, else: 0.0
    
    dropout_penalty = if params.dropout_1 > 0.5, do: -0.03, else: 0.0
    
    # Activation synergy  
    activation_bonus = case {params.activation_1, params.activation_2} do
      {"relu", "relu"} -> 0.02
      {"gelu", "relu"} -> 0.03  
      {"swish", "sigmoid"} -> 0.025
      _ -> 0.0
    end
    
    layer_balance + depth_bonus + size_bonus + dropout_penalty + activation_bonus
  end
  
  defp calculate_training_score(params) do
    # Learning rate sweet spots
    lr_score = cond do
      params.learning_rate >= 0.001 and params.learning_rate <= 0.01 -> 0.06
      params.learning_rate >= 0.0001 and params.learning_rate <= 0.1 -> 0.03
      true -> -0.03
    end
    
    # Batch size impact
    batch_score = case params.batch_size do
      bs when bs >= 32 and bs <= 64 -> 0.02
      bs when bs >= 16 -> 0.01
      _ -> -0.01
    end
    
    # Regularization balance
    reg_score = if params.weight_decay > 1.0e-5 and params.weight_decay < 1.0e-2, do: 0.02, else: -0.01
    
    lr_score + batch_score + reg_score
  end
  
  defp calculate_optimizer_score(params) do
    opt_score = case params.optimizer do
      "adam" -> 0.04
      "rmsprop" -> 0.03
      "sgd" -> 0.02
      _ -> 0.01
    end
    
    scheduler_score = case params.lr_scheduler do
      "cosine" -> 0.02
      "step" -> 0.01
      _ -> 0.0
    end
    
    opt_score + scheduler_score
  end
end

# Test the dashboard with multiple concurrent studies
IO.puts("""
🚀 TESTING SCOUT'S PHOENIX DASHBOARD
====================================
Creating multiple studies to test dashboard visualization:
""")

# Start Scout application manually (since we can't use mix run)
Application.ensure_all_started(:scout_dashboard)

# Study 1: TPE with aggressive settings
study1 = %Scout.Study{
  id: "dashboard_test_tpe_#{System.system_time(:second)}",
  goal: :maximize,
  max_trials: 30,
  parallelism: 2,
  search_space: &DashboardTestStudy.search_space/1,
  objective: &DashboardTestStudy.objective/2,  # 2-arity for pruning
  sampler: Scout.Sampler.TPE,
  sampler_opts: %{
    gamma: 0.20,        # Top 20% are good
    min_obs: 6,         # Switch to TPE early
    n_candidates: 32,   # Many candidates
    multivariate: true
  },
  pruner: Scout.Pruner.Hyperband,
  pruner_opts: %{
    eta: 3,             # Aggressive pruning
    max_resource: 20,   # 20 epochs max
    warmup_peers: 4     # Start pruning early
  },
  metadata: %{description: "TPE + Hyperband: Aggressive optimization"}
}

IO.puts("📊 Study 1: #{study1.id}")
IO.puts("   Sampler: TPE (γ=0.20, multivariate)")  
IO.puts("   Pruner: Hyperband (η=3, max=20 epochs)")
IO.puts("   Trials: #{study1.max_trials}")

# Study 2: Random baseline for comparison
study2 = %Scout.Study{
  id: "dashboard_test_random_#{System.system_time(:second)}",
  goal: :maximize,
  max_trials: 25,
  parallelism: 1,
  search_space: &DashboardTestStudy.search_space/1,
  objective: &DashboardTestStudy.objective/2,
  sampler: Scout.Sampler.RandomSearch,
  sampler_opts: %{},
  pruner: Scout.Pruner.Hyperband,
  pruner_opts: %{eta: 3, max_resource: 20, warmup_peers: 4},
  metadata: %{description: "Random + Hyperband: Baseline comparison"}
}

IO.puts("📊 Study 2: #{study2.id}")
IO.puts("   Sampler: Random (baseline)")
IO.puts("   Pruner: Hyperband (same config)")
IO.puts("   Trials: #{study2.max_trials}")

IO.puts("""

🌐 DASHBOARD ACCESS:
Open your browser to: http://localhost:4000

Expected dashboard features:
✅ Real-time study progress tracking
✅ Hyperband bracket visualization  
✅ Best score sparkline charts
✅ Trial status (running/completed/pruned)
✅ Live parameter updates

Note: Studies will appear in dashboard as they run.
You can monitor the TPE vs Random comparison in real-time!
""")

# Run studies sequentially to avoid conflicts
IO.puts("\n🚀 Starting Study 1 (TPE)...")
:rand.seed(:exsplus, {42, 1, 1})
result1 = Scout.StudyRunner.run(study1)

IO.puts("\n🚀 Starting Study 2 (Random)...")  
:rand.seed(:exsplus, {42, 2, 2})
result2 = Scout.StudyRunner.run(study2)

IO.puts("\n📊 STUDY COMPARISON RESULTS:")
IO.puts("=" * 50)

IO.puts("TPE Study:")
IO.puts("  Best score: #{Float.round(result1.best_score, 6)}")
IO.puts("  Best params: #{inspect(result1.best_params)}")

IO.puts("\nRandom Study:")  
IO.puts("  Best score: #{Float.round(result2.best_score, 6)}")
IO.puts("  Best params: #{inspect(result2.best_params)}")

improvement = (result1.best_score - result2.best_score) / result2.best_score * 100
IO.puts("\n🏆 TPE vs Random:")
IO.puts("  Improvement: #{Float.round(improvement, 1)}%")

if improvement > 5 do
  IO.puts("  ✅ TPE significantly outperformed Random!")
else
  IO.puts("  📊 Performance was similar (#{Float.round(improvement, 1)}% difference)")
end

IO.puts("""

✅ DASHBOARD TEST COMPLETE!
Both studies should now be visible in the Phoenix dashboard.
The dashboard provides real-time monitoring that beats static plots.
""")