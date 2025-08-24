#!/usr/bin/env elixir

# Scout Demo - Hyperparameter Optimization Framework
# Demonstrating core capabilities

IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("       Scout - Distributed Hyperparameter Optimization")
IO.puts("                    Version 0.3")
IO.puts(String.duplicate("=", 60))

# 1. Simple optimization with Random Sampler
IO.puts("\n📊 Demo 1: Random Search Optimization")
IO.puts("Finding minimum of quadratic function: (x-2)² + (y+3)²")

study1 = %Scout.Study{
  id: "demo_random_#{System.system_time(:millisecond)}",
  goal: :minimize,
  max_trials: 20,
  parallelism: 1,
  search_space: fn _ix ->
    %{
      x: {:uniform, -10.0, 10.0},
      y: {:uniform, -10.0, 10.0}
    }
  end,
  objective: fn params ->
    x = params[:x] || params["x"]
    y = params[:y] || params["y"]
    (x - 2.0) ** 2 + (y + 3.0) ** 2
  end,
  sampler: Scout.Sampler.Random,
  sampler_opts: %{},
  seed: 42
}

{:ok, result1} = Scout.run(study1)
IO.puts("✅ Best value found: #{Float.round(result1.best_score, 4)}")
IO.puts("   Best params: x=#{Float.round(result1.best_params[:x], 2)}, y=#{Float.round(result1.best_params[:y], 2)}")
IO.puts("   Target was: x=2.0, y=-3.0")

# 2. TPE Sampler with multivariate support
IO.puts("\n📊 Demo 2: TPE with Multivariate Correlation")
IO.puts("Optimizing Rosenbrock function (correlated parameters)")

study2 = %Scout.Study{
  id: "demo_tpe_#{System.system_time(:millisecond)}",
  goal: :minimize,
  max_trials: 50,
  parallelism: 1,
  search_space: fn _ix ->
    %{
      x: {:uniform, -5.0, 5.0},
      y: {:uniform, -5.0, 5.0}
    }
  end,
  objective: fn params ->
    x = params[:x] || params["x"]
    y = params[:y] || params["y"]
    # Rosenbrock function - optimal at (1, 1)
    100 * (y - x ** 2) ** 2 + (1 - x) ** 2
  end,
  sampler: Scout.Sampler.TPE,
  sampler_opts: %{
    gamma: 0.25,
    n_candidates: 24,
    min_obs: 10,
    multivariate: true  # Enable correlation modeling
  },
  seed: 42
}

{:ok, result2} = Scout.run(study2)
IO.puts("✅ Best value found: #{Float.round(result2.best_score, 4)}")
IO.puts("   Best params: x=#{Float.round(result2.best_params[:x], 2)}, y=#{Float.round(result2.best_params[:y], 2)}")
IO.puts("   Target was: x=1.0, y=1.0")

# 3. Grid Search
IO.puts("\n📊 Demo 3: Grid Search")
IO.puts("Systematic parameter exploration")

study3 = %Scout.Study{
  id: "demo_grid_#{System.system_time(:millisecond)}",
  goal: :minimize,
  max_trials: 16,  # 4x4 grid
  parallelism: 1,
  search_space: fn _ix ->
    %{
      x: {:uniform, -2.0, 2.0},
      y: {:uniform, -2.0, 2.0}
    }
  end,
  objective: fn params ->
    x = params[:x] || params["x"]
    y = params[:y] || params["y"]
    # Simple quadratic
    x ** 2 + y ** 2
  end,
  sampler: Scout.Sampler.Grid,
  sampler_opts: %{
    resolution: %{x: 4, y: 4}
  }
}

{:ok, result3} = Scout.run(study3)
IO.puts("✅ Best value found: #{Float.round(result3.best_score, 4)}")
IO.puts("   Best params: x=#{Float.round(result3.best_params[:x], 2)}, y=#{Float.round(result3.best_params[:y], 2)}")

# 4. Simulated ML hyperparameter optimization
IO.puts("\n📊 Demo 4: ML Hyperparameter Optimization")
IO.puts("Simulating neural network training")

study4 = %Scout.Study{
  id: "demo_ml_#{System.system_time(:millisecond)}",
  goal: :minimize,
  max_trials: 30,
  parallelism: 1,
  search_space: fn _ix ->
    %{
      learning_rate: {:log_uniform, 1.0e-5, 1.0e-1},
      dropout: {:uniform, 0.0, 0.5},
      batch_size: {:choice, [16, 32, 64, 128]},
      optimizer: {:choice, ["adam", "sgd", "rmsprop"]}
    }
  end,
  objective: fn params ->
    lr = params[:learning_rate] || params["learning_rate"]
    dropout = params[:dropout] || params["dropout"]
    batch = params[:batch_size] || params["batch_size"]
    opt = params[:optimizer] || params["optimizer"]
    
    # Simulated loss function
    base_loss = -:math.log10(lr) * 0.3  # Prefer moderate learning rates
    
    dropout_penalty = abs(dropout - 0.3) * 2  # Optimal around 0.3
    
    batch_penalty = case batch do
      32 -> 0.0  # Optimal
      64 -> 0.1
      16 -> 0.2
      128 -> 0.3
      _ -> 0.5
    end
    
    optimizer_bonus = case opt do
      "adam" -> -0.2  # Best
      "rmsprop" -> 0.0
      "sgd" -> 0.1
      _ -> 0.3
    end
    
    # Add some noise to simulate training variance
    noise = :rand.uniform() * 0.1
    
    base_loss + dropout_penalty + batch_penalty + optimizer_bonus + noise
  end,
  sampler: Scout.Sampler.TPE,
  sampler_opts: %{
    gamma: 0.25,
    n_candidates: 24,
    min_obs: 10
  }
}

{:ok, result4} = Scout.run(study4)
IO.puts("✅ Best validation loss: #{Float.round(result4.best_score, 4)}")
IO.puts("   Best hyperparameters:")
IO.puts("   - Learning rate: #{Float.round(result4.best_params[:learning_rate], 6)}")
IO.puts("   - Dropout: #{Float.round(result4.best_params[:dropout], 3)}")
IO.puts("   - Batch size: #{result4.best_params[:batch_size]}")
IO.puts("   - Optimizer: #{result4.best_params[:optimizer]}")

# Summary
IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("                    Demo Complete!")
IO.puts(String.duplicate("=", 60))
IO.puts("\n✨ Scout Features Demonstrated:")
IO.puts("   • Random Search - Simple baseline optimization")
IO.puts("   • TPE with Multivariate - Correlation-aware sampling")
IO.puts("   • Grid Search - Systematic exploration")
IO.puts("   • Mixed parameter types - Continuous, log, choice")
IO.puts("\n🚀 Ready for production use!")
IO.puts("   Check out docs/ for integration guides")
IO.puts("   Run with Oban executor for distributed optimization")