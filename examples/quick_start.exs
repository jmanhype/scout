#!/usr/bin/env elixir

# Quick Start Example - Demonstrates Scout's Simple API
# Matches Optuna's ease of use with Elixir's power

IO.puts "\n=== Scout Quick Start Example ==="
IO.puts "Optimizing a simple quadratic function\n"

# Load Scout modules
Code.require_file("../lib/scout/easy.ex")

# 1. Define your objective function
objective = fn trial ->
  # Suggest hyperparameters
  x = Scout.Trial.suggest_float(trial, "x", -10, 10)
  y = Scout.Trial.suggest_float(trial, "y", -10, 10)
  
  # Return value to minimize
  (x - 2) ** 2 + (y + 5) ** 2
end

# 2. Create and run study (3 lines!)
study = Scout.Easy.create_study(direction: :minimize)
Scout.Easy.optimize(study, objective, n_trials: 50)
best = Scout.Easy.best_params(study)

# 3. Display results
IO.puts "Optimization complete!"
IO.puts "Best parameters found:"
IO.puts "  x = #{best[:x]}"
IO.puts "  y = #{best[:y]}"
IO.puts "Best value: #{Scout.Easy.best_value(study)}"

# Advanced example with ML hyperparameter optimization
IO.puts "\n=== ML Hyperparameter Optimization Example ==="

ml_objective = fn trial ->
  # Suggest ML hyperparameters
  learning_rate = Scout.Trial.suggest_float(trial, "learning_rate", 1.0e-5, 1.0e-1, log: true)
  n_layers = Scout.Trial.suggest_int(trial, "n_layers", 1, 5)
  dropout = Scout.Trial.suggest_float(trial, "dropout", 0.0, 0.5)
  optimizer = Scout.Trial.suggest_categorical(trial, "optimizer", ["adam", "sgd", "rmsprop"])
  
  # Simulate model training (replace with actual training)
  simulated_loss = learning_rate * 100 + n_layers * 0.1 - dropout * 0.5 +
    case optimizer do
      "adam" -> 0.0
      "sgd" -> 0.2
      "rmsprop" -> 0.1
    end
  
  # Add some noise to simulate real training
  simulated_loss + :rand.uniform() * 0.1
end

# Run ML optimization with pruning
ml_study = Scout.Easy.create_study(
  study_name: "ml_hyperopt",
  direction: :minimize,
  pruner: Scout.Pruner.MedianPruner
)

Scout.Easy.optimize(ml_study, ml_objective, n_trials: 30)
ml_best = Scout.Easy.best_params(ml_study)

IO.puts "\nBest ML hyperparameters:"
IO.puts "  Learning rate: #{ml_best[:learning_rate]}"
IO.puts "  Number of layers: #{ml_best[:n_layers]}"
IO.puts "  Dropout: #{ml_best[:dropout]}"
IO.puts "  Optimizer: #{ml_best[:optimizer]}"
IO.puts "Best validation loss: #{Scout.Easy.best_value(ml_study)}"

IO.puts "\n✅ Scout is ready for production use!"
IO.puts "Check out comprehensive_demo.exs for all features"