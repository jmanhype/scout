# Advanced ML Study Configuration for Scout
# This file returns a study map for the CLI

# Define search space for ML hyperparameters
search_space = fn _ix ->
  %{
    # Neural network architecture
    n_layers: {:int, 2, 5},
    hidden_size: {:int, 32, 128},
    dropout_rate: {:uniform, 0.1, 0.4},
    
    # Training hyperparameters  
    learning_rate: {:log_uniform, 1.0e-4, 1.0e-1},
    batch_size: {:int, 16, 64},
    
    # Optimization settings
    optimizer: {:choice, ["adam", "sgd", "rmsprop"]},
    weight_decay: {:log_uniform, 1.0e-5, 1.0e-2}
  }
end

# Define objective function - simulates ML training
objective = fn params ->
  # Simulate neural network training with realistic performance
  base_accuracy = 0.75
  
  # Architecture impact
  arch_boost = case {params.n_layers, params.hidden_size} do
    {n, h} when n >= 3 and n <= 4 and h >= 64 -> 0.08
    {n, h} when n >= 2 and h >= 32 -> 0.04
    _ -> -0.02
  end
  
  # Learning rate impact (sweet spot around 0.001-0.01)
  lr_boost = cond do
    params.learning_rate >= 0.001 and params.learning_rate <= 0.01 -> 0.06
    params.learning_rate >= 0.0001 and params.learning_rate <= 0.1 -> 0.02
    true -> -0.04
  end
  
  # Optimizer impact
  opt_boost = case params.optimizer do
    "adam" -> 0.04
    "sgd" -> 0.01
    _ -> 0.02
  end
  
  # Regularization impact
  reg_boost = if params.dropout_rate > 0.15 and params.dropout_rate < 0.35 do
    0.03
  else
    -0.01
  end
  
  # Add realistic noise
  noise = (:rand.uniform() - 0.5) * 0.02
  
  # Calculate final accuracy
  accuracy = base_accuracy + arch_boost + lr_boost + opt_boost + reg_boost + noise
  max(0.65, min(0.95, accuracy))
end

# Return the study configuration as Scout.Study struct
%Scout.Study{
  id: "advanced_ml_study_#{System.system_time(:second)}",
  goal: :maximize,
  max_trials: 25,
  parallelism: 1,        # Required field
  search_space: search_space,
  objective: objective,
  sampler: Scout.Sampler.TPE,
  sampler_opts: %{
    gamma: 0.25,           # Top 25% are "good" 
    min_obs: 8,           # Switch to TPE after 8 trials
    n_candidates: 24,     # Generate 24 candidates per iteration
    multivariate: true   # Enable multivariate modeling
  }
}