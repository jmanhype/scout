# Examples

Comprehensive examples demonstrating Scout's capabilities for various optimization tasks.

## Basic Examples

### Simple Function Optimization
Optimize mathematical functions to understand Scout's API:

```elixir
# Rosenbrock function - a classic optimization benchmark
result = Scout.Easy.optimize(
  fn params ->
    a = 1
    b = 100
    (a - params.x)**2 + b * (params.y - params.x**2)**2
  end,
  %{
    x: {:uniform, -5, 5},
    y: {:uniform, -5, 5}
  },
  n_trials: 200,
  sampler: :tpe
)

IO.puts("Optimum found at: (#{result.best_params.x}, #{result.best_params.y})")
# Should be close to (1, 1)
```

### Multi-dimensional Sphere Function
```elixir
# 10-dimensional sphere function
dimensions = 10
search_space = for i <- 1..dimensions, into: %{} do
  {"x#{i}", {:uniform, -5.12, 5.12}}
end

result = Scout.Easy.optimize(
  fn params ->
    params
    |> Map.values()
    |> Enum.map(&(&1 ** 2))
    |> Enum.sum()
  end,
  search_space,
  n_trials: 500,
  sampler: :cmaes  # CMA-ES works well for continuous optimization
)
```

## Machine Learning Examples

### Neural Network Hyperparameter Tuning
Complete example with Axon (Elixir's neural network library):

```elixir
defmodule MLOptimization do
  import Axon
  
  def build_model(params) do
    input = input("features", shape: {nil, 784})
    
    # Build dynamic architecture based on params
    hidden = 
      Enum.reduce(1..params.n_layers, input, fn i, layer ->
        layer
        |> dense(params["layer_#{i}_units"], activation: params.activation)
        |> dropout(rate: params.dropout)
      end)
    
    hidden |> dense(10, activation: :softmax)
  end
  
  def train_and_evaluate(params) do
    model = build_model(params)
    
    {init_fn, predict_fn} = Axon.build(model)
    
    params = init_fn.(Nx.template({1, 784}, :f32), %{})
    
    # Training loop with early stopping
    {final_params, best_accuracy} = 
      train_loop(
        model,
        params,
        learning_rate: params.learning_rate,
        batch_size: params.batch_size,
        epochs: 20
      )
    
    best_accuracy
  end
end

# Optimize the neural network
result = Scout.Easy.optimize(
  &MLOptimization.train_and_evaluate/1,
  %{
    n_layers: {:int, 1, 5},
    layer_1_units: {:int, 32, 512},
    layer_2_units: {:int, 32, 512},
    layer_3_units: {:int, 32, 512},
    layer_4_units: {:int, 32, 512},
    layer_5_units: {:int, 32, 512},
    activation: {:choice, [:relu, :tanh, :sigmoid]},
    dropout: {:uniform, 0, 0.5},
    learning_rate: {:log_uniform, 1e-5, 1e-1},
    batch_size: {:choice, [16, 32, 64, 128]}
  },
  n_trials: 100,
  pruner: :median,  # Prune based on median performance
  dashboard: true
)
```

### XGBoost-style Gradient Boosting
```elixir
result = Scout.Easy.optimize(
  fn params ->
    model = GradientBoosting.train(
      training_data,
      n_estimators: params.n_estimators,
      max_depth: params.max_depth,
      learning_rate: params.learning_rate,
      subsample: params.subsample,
      colsample_bytree: params.colsample_bytree,
      min_child_weight: params.min_child_weight,
      gamma: params.gamma,
      reg_alpha: params.reg_alpha,
      reg_lambda: params.reg_lambda
    )
    
    # Return cross-validation score
    cross_validate(model, training_data, folds: 5)
  end,
  %{
    n_estimators: {:int, 50, 500},
    max_depth: {:int, 3, 10},
    learning_rate: {:log_uniform, 0.01, 0.3},
    subsample: {:uniform, 0.6, 1.0},
    colsample_bytree: {:uniform, 0.6, 1.0},
    min_child_weight: {:int, 1, 10},
    gamma: {:uniform, 0, 0.5},
    reg_alpha: {:log_uniform, 1e-8, 10},
    reg_lambda: {:log_uniform, 1e-8, 10}
  },
  n_trials: 200,
  sampler: :tpe,
  sampler_opts: %{multivariate: true}  # Consider parameter correlations
)
```

## Advanced Optimization Patterns

### Multi-Objective Optimization
Optimize for multiple competing objectives:

```elixir
# Optimize model accuracy vs inference time
result = Scout.Easy.optimize(
  fn params ->
    model = build_model(params)
    accuracy = evaluate_accuracy(model)
    inference_time = measure_inference_time(model)
    
    # Return both objectives
    [accuracy, -inference_time]  # Maximize accuracy, minimize time
  end,
  search_space,
  n_trials: 200,
  n_objectives: 2,
  sampler: :nsga2,  # Non-dominated Sorting Genetic Algorithm
  reference_point: [0.95, -0.1]  # Target: 95% accuracy, <100ms inference
)

# Get Pareto front
pareto_trials = Scout.get_pareto_front_trials(result.study)
```

### Conditional Search Spaces
Handle dependencies between parameters:

```elixir
search_space = %{
  model_type: {:choice, ["linear", "tree", "neural"]},
  
  # Linear model parameters
  regularization: {:choice, ["l1", "l2", "elastic"], 
                  when: {:model_type, "linear"}},
  alpha: {:log_uniform, 1e-5, 10, 
         when: {:model_type, "linear"}},
  
  # Tree model parameters
  max_depth: {:int, 3, 20, 
             when: {:model_type, "tree"}},
  min_samples_split: {:int, 2, 20, 
                      when: {:model_type, "tree"}},
  
  # Neural network parameters
  n_hidden_layers: {:int, 1, 5, 
                   when: {:model_type, "neural"}},
  hidden_units: {:int, 32, 512, 
                when: {:model_type, "neural"}}
}
```

### Distributed Optimization
Leverage multiple nodes for parallel trials:

```elixir
# Connect to worker nodes
Node.connect(:"worker1@host1")
Node.connect(:"worker2@host2")
Node.connect(:"worker3@host3")

result = Scout.Easy.optimize(
  fn params ->
    # This will run on different nodes
    expensive_simulation(params)
  end,
  search_space,
  n_trials: 1000,
  parallelism: 20,  # 20 concurrent trials across cluster
  executor: :distributed,
  timeout: :timer.minutes(30)  # Long-running trials
)
```

### Warm Starting with Prior Knowledge
Use results from previous optimizations:

```elixir
# Load previous study
previous_study = Scout.load_study("previous_optimization")

# Extract best trials as priors
priors = Scout.get_best_trials(previous_study, n: 10)

# Start new optimization with transfer learning
result = Scout.Easy.optimize(
  updated_objective,
  search_space,
  n_trials: 100,
  sampler: :tpe,
  sampler_opts: %{
    prior_weight: 0.3,  # Weight for prior knowledge
    prior_trials: priors
  }
)
```

## Real-World Applications

### A/B Test Configuration
```elixir
# Optimize webpage elements for conversion
result = Scout.Easy.optimize(
  fn params ->
    # Run simulated A/B test
    conversion_rate = simulate_ab_test(
      button_color: params.button_color,
      button_text: params.button_text,
      header_size: params.header_size,
      cta_position: params.cta_position,
      n_users: 1000
    )
  end,
  %{
    button_color: {:choice, ["red", "green", "blue", "orange"]},
    button_text: {:choice, ["Buy Now", "Get Started", "Learn More"]},
    header_size: {:int, 24, 48},
    cta_position: {:choice, ["top", "middle", "bottom"]}
  },
  n_trials: 50
)
```

### Database Query Optimization
```elixir
# Optimize database configuration
result = Scout.Easy.optimize(
  fn params ->
    # Apply configuration
    configure_database(params)
    
    # Run benchmark queries
    latencies = run_benchmark_suite()
    
    # Return p95 latency (to minimize)
    Statistics.percentile(latencies, 95)
  end,
  %{
    connection_pool_size: {:int, 10, 100},
    query_timeout: {:int, 100, 5000},
    cache_size_mb: {:int, 128, 2048},
    work_mem_mb: {:int, 4, 64},
    shared_buffers_mb: {:int, 128, 4096},
    effective_cache_size_gb: {:int, 1, 16}
  },
  n_trials: 100,
  pruner: :patient  # Don't prune too early for noisy metrics
)
```

## Running the Examples

All examples can be found in the `examples/` directory:

```bash
# Basic optimization
mix run examples/quick_start.exs

# ML optimization demo
mix run examples/demo_scout.exs

# Real-world usage
mix run examples/real_usage_example.exs

# Performance validation
mix run examples/proof_scripts/prove_scout.exs

# Dashboard demo
mix scout.demo
```

## Next Steps

- Learn about [Study Management](../concepts/study-management.md)
- Explore [Advanced Samplers](../api/samplers.md)
- Set up [Distributed Optimization](../deployment/distributed.md)
- Review [Performance Benchmarks](../benchmarks/comparison.md)