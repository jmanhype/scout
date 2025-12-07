#!/usr/bin/env elixir

# Test Scout's Easy API - this is how you'd actually use it
Mix.install([{:scout, path: "."}])

# Start the application
Application.ensure_all_started(:scout)

IO.puts "\n=== Testing Scout Easy API (Like Optuna) ===\n"

# Test 1: Simple optimization exactly like Optuna
IO.puts "1. Basic usage (3 lines like Optuna):"
result = Scout.Easy.optimize(
  fn params -> (params.x - 2) ** 2 + (params.y + 5) ** 2 end,
  %{x: {:uniform, -10, 10}, y: {:uniform, -10, 10}},
  n_trials: 20
)

IO.puts "Best: #{result.best_value}"
IO.puts "Params: x=#{result.best_params.x}, y=#{result.best_params.y}\n"

# Test 2: ML hyperparameter optimization (real use case)
IO.puts "2. ML Hyperparameter Optimization:"
ml_result = Scout.Easy.optimize(
  fn params ->
    # Simulate model training
    lr = params.learning_rate
    dropout = params.dropout
    layers = params.n_layers
    
    # Fake validation loss
    base_loss = -:math.log10(lr) * 0.3
    dropout_penalty = abs(dropout - 0.3) * 0.5
    layer_penalty = layers * 0.05
    
    base_loss + dropout_penalty + layer_penalty + :rand.uniform() * 0.1
  end,
  %{
    learning_rate: {:log_uniform, 1.0e-5, 1.0e-1},
    dropout: {:uniform, 0.0, 0.5},
    n_layers: {:int, 2, 10}
  },
  n_trials: 30,
  direction: :minimize
)

IO.puts "Best loss: #{Float.round(ml_result.best_value, 4)}"
IO.puts "Best hyperparameters:"
IO.puts "  Learning rate: #{ml_result.best_params.learning_rate}"
IO.puts "  Dropout: #{Float.round(ml_result.best_params.dropout, 3)}"
IO.puts "  Layers: #{ml_result.best_params.n_layers}\n"

IO.puts "✅ Scout Easy API works just like Optuna!"