# Quick Start Guide

Get up and running with Scout in minutes! This guide shows you how to optimize your first function.

## Your First Optimization (3 Lines!)

Scout matches Optuna's simplicity with Elixir's power:

```elixir
# Optimize a simple function
result = Scout.Easy.optimize(
  fn params -> -(params.x**2 + params.y**2) end,  # Maximize negative quadratic
  %{x: {:uniform, -5.0, 5.0}, y: {:uniform, -5.0, 5.0}},
  n_trials: 100
)

IO.puts("Best score: #{result.best_score}")
IO.puts("Best params: #{inspect(result.best_params)}")
# Output: Best params: %{x: 0.001, y: -0.002}
```

That's it! Scout automatically:
- ✅ Starts all required infrastructure
- ✅ Uses advanced TPE sampler by default
- ✅ Handles errors gracefully
- ✅ Returns results in a simple format

## Understanding the API

### The Objective Function
Your objective function receives a `params` map and returns a value to optimize:

```elixir
objective = fn params ->
  # Use suggested parameters
  x = params.x
  y = params.y
  
  # Calculate and return the metric
  (x - 2)**2 + (y + 5)**2  # Minimize distance to (2, -5)
end
```

### The Search Space
Define the hyperparameter search space with distributions:

```elixir
search_space = %{
  # Continuous parameters
  learning_rate: {:log_uniform, 1e-5, 1e-1},  # Log-scale sampling
  dropout: {:uniform, 0.0, 0.5},              # Linear sampling
  
  # Discrete parameters  
  n_layers: {:int, 2, 8},                     # Integer range
  batch_size: {:choice, [16, 32, 64, 128]},   # Categorical
  
  # Boolean parameters
  use_batch_norm: {:choice, [true, false]}
}
```

## Real ML Example

Here's a complete machine learning optimization:

```elixir
# Define your ML training function
train_model = fn params ->
  model = NeuralNetwork.build(
    layers: params.n_layers,
    neurons: params.neurons_per_layer,
    activation: params.activation
  )
  
  model
  |> NeuralNetwork.compile(
    optimizer: params.optimizer,
    learning_rate: params.learning_rate
  )
  |> NeuralNetwork.fit(
    train_data,
    epochs: 10,
    batch_size: params.batch_size
  )
  
  # Return validation accuracy
  NeuralNetwork.evaluate(model, val_data)
end

# Optimize hyperparameters
result = Scout.Easy.optimize(
  train_model,
  %{
    n_layers: {:int, 2, 8},
    neurons_per_layer: {:int, 32, 512},
    activation: {:choice, ["relu", "tanh", "sigmoid"]},
    optimizer: {:choice, ["adam", "sgd", "rmsprop"]},
    learning_rate: {:log_uniform, 1e-5, 1e-1},
    batch_size: {:choice, [16, 32, 64, 128]}
  },
  n_trials: 50,
  direction: :maximize,  # Maximize accuracy
  dashboard: true        # Enable real-time monitoring
)

IO.puts("Best accuracy: #{result.best_score}")
IO.puts("Best hyperparameters:")
IO.inspect(result.best_params)
```

## Monitoring Progress

### Real-Time Dashboard
When `dashboard: true`, Scout provides a Phoenix LiveView dashboard:

```elixir
result = Scout.Easy.optimize(
  objective,
  search_space,
  n_trials: 100,
  dashboard: true  # Enable dashboard
)

# Access at http://localhost:4050
# Features:
# - Live trial progress
# - Parameter importance plots
# - Optimization history
# - Parallel trial monitoring
```

### Programmatic Monitoring
Track progress in your code:

```elixir
result = Scout.Easy.optimize(
  objective,
  search_space,
  n_trials: 100,
  callback: fn trial_result ->
    IO.puts("Trial #{trial_result.number}: #{trial_result.value}")
  end
)
```

## Early Stopping with Pruners

Stop unpromising trials early to save compute:

```elixir
result = Scout.Easy.optimize(
  fn params, report_fn ->
    model = create_model(params)
    
    # Training with intermediate reporting
    for epoch <- 1..20 do
      loss = train_epoch(model, params)
      
      # Report intermediate value for pruning decision
      case report_fn.(loss, epoch) do
        :continue -> :ok
        :prune -> throw(:pruned)  # Stop this trial
      end
    end
    
    final_validation_score(model)
  end,
  search_space,
  n_trials: 100,
  pruner: :hyperband,  # Aggressive early stopping
  pruner_opts: %{
    min_resource: 1,
    max_resource: 20,
    reduction_factor: 3
  }
)
```

## Parallel Optimization

Leverage Elixir's concurrency:

```elixir
result = Scout.Easy.optimize(
  expensive_objective,
  search_space,
  n_trials: 100,
  parallelism: 8,  # Run 8 trials concurrently
  executor: :async  # Use async Tasks
)
```

## Common Patterns

### Minimization vs Maximization
```elixir
# Minimize (default)
Scout.Easy.optimize(objective, space, n_trials: 50)

# Maximize
Scout.Easy.optimize(objective, space, n_trials: 50, direction: :maximize)
```

### Multi-Objective Optimization
```elixir
result = Scout.Easy.optimize(
  fn params ->
    accuracy = train_and_evaluate(params)
    model_size = calculate_model_size(params)
    
    # Return multiple objectives
    [accuracy, -model_size]  # Maximize accuracy, minimize size
  end,
  search_space,
  n_trials: 100,
  n_objectives: 2,
  sampler: :nsga2  # Multi-objective genetic algorithm
)
```

### Conditional Parameters
```elixir
search_space = %{
  algorithm: {:choice, ["svm", "random_forest"]},
  # SVM-specific parameters (only used when algorithm="svm")
  svm_kernel: {:choice, ["linear", "rbf"], when: {:algorithm, "svm"}},
  svm_c: {:log_uniform, 0.01, 100, when: {:algorithm, "svm"}},
  # Random Forest parameters  
  rf_n_trees: {:int, 10, 100, when: {:algorithm, "random_forest"}},
  rf_max_depth: {:int, 3, 20, when: {:algorithm, "random_forest"}}
}
```

## Next Steps

- Explore [Advanced Examples](examples.md) for complex use cases
- Learn about [DSPy Integration](../concepts/dspy-integration.md)
- Understand [Hyperparameter Optimization](../concepts/hyperparameter-optimization.md)
- Set up [Production Deployment](../deployment/docker.md)