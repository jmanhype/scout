# Hyperparameter Optimization

Understanding Scout's approach to hyperparameter optimization and the algorithms it provides.

## Core Concepts

### What are Hyperparameters?
Hyperparameters are configuration values that control the learning process:
- **Model architecture**: layers, neurons, activation functions
- **Training process**: learning rate, batch size, epochs
- **Regularization**: dropout, L1/L2 penalties
- **Algorithm-specific**: tree depth, kernel type, cluster count

### The Optimization Problem
Finding the best hyperparameters is challenging because:
- The search space is often high-dimensional
- Evaluations are expensive (training takes time)
- The objective function is noisy
- Parameters interact in complex ways

## Scout's Optimization Algorithms

### Tree-structured Parzen Estimator (TPE)
Scout's default and most sophisticated sampler:

```elixir
result = Scout.Easy.optimize(
  objective,
  search_space,
  sampler: :tpe,
  sampler_opts: %{
    n_startup_trials: 10,     # Random trials before modeling
    n_ei_candidates: 24,      # Candidates for acquisition
    gamma: 0.25,              # Quantile threshold
    multivariate: true        # Model parameter correlations
  }
)
```

**How TPE Works:**
1. Separates trials into "good" (top γ%) and "bad"
2. Models P(x|good) and P(x|bad) distributions
3. Maximizes ratio P(x|good)/P(x|bad) for next trial
4. Handles continuous, discrete, and categorical parameters

### CMA-ES (Covariance Matrix Adaptation)
Best for continuous optimization problems:

```elixir
result = Scout.Easy.optimize(
  objective,
  continuous_search_space,
  sampler: :cmaes,
  sampler_opts: %{
    sigma: 1.0,          # Initial step size
    population_size: 20  # λ parameter
  }
)
```

**When to Use CMA-ES:**
- Continuous parameters only
- Smooth objective landscape
- Need rotation-invariant optimization
- Problems with correlated parameters

### NSGA-II (Multi-Objective)
For optimizing multiple competing objectives:

```elixir
result = Scout.Easy.optimize(
  fn params -> [accuracy(params), -latency(params)] end,
  search_space,
  n_objectives: 2,
  sampler: :nsga2,
  sampler_opts: %{
    population_size: 50,
    mutation_rate: 0.1,
    crossover_rate: 0.9
  }
)
```

**Features:**
- Pareto front approximation
- Non-dominated sorting
- Crowding distance for diversity
- Elitism to preserve best solutions

### Grid Search
Exhaustive search over discrete combinations:

```elixir
result = Scout.Easy.optimize(
  objective,
  %{
    learning_rate: {:choice, [0.001, 0.01, 0.1]},
    batch_size: {:choice, [16, 32, 64]},
    optimizer: {:choice, ["adam", "sgd"]}
  },
  sampler: :grid
)
# Will test all 3 × 3 × 2 = 18 combinations
```

### Random Search
Simple but surprisingly effective:

```elixir
result = Scout.Easy.optimize(
  objective,
  search_space,
  sampler: :random,
  n_trials: 100
)
```

**Why Random Search Works:**
- High-dimensional spaces
- Important parameters dominate
- No modeling overhead
- Good baseline for comparison

## Search Space Definition

### Distribution Types

```elixir
search_space = %{
  # Uniform distribution [a, b]
  dropout: {:uniform, 0.0, 0.5},
  
  # Log-uniform distribution (multiplicative)
  learning_rate: {:log_uniform, 1e-5, 1e-1},
  
  # Integer range [a, b]
  n_layers: {:int, 2, 8},
  
  # Categorical choice
  activation: {:choice, ["relu", "tanh", "sigmoid"]},
  
  # Integer with log-scale
  batch_size: {:int_log_uniform, 8, 256},
  
  # Discrete uniform (with step)
  momentum: {:discrete_uniform, 0.5, 0.99, step: 0.01}
}
```

### Conditional Parameters

Define parameters that depend on others:

```elixir
search_space = %{
  algorithm: {:choice, ["svm", "random_forest", "neural_net"]},
  
  # SVM-specific
  kernel: {:choice, ["rbf", "linear"], when: {:algorithm, "svm"}},
  C: {:log_uniform, 0.01, 100, when: {:algorithm, "svm"}},
  gamma: {:log_uniform, 0.001, 1, when: [{:algorithm, "svm"}, {:kernel, "rbf"}]},
  
  # Random Forest specific
  n_trees: {:int, 10, 200, when: {:algorithm, "random_forest"}},
  max_depth: {:int, 3, 20, when: {:algorithm, "random_forest"}},
  
  # Neural Network specific
  n_hidden: {:int, 1, 5, when: {:algorithm, "neural_net"}},
  hidden_size: {:int, 32, 512, when: {:algorithm, "neural_net"}}
}
```

## Pruning Strategies

### Median Pruner
Stops trials performing worse than median:

```elixir
result = Scout.Easy.optimize(
  progressive_objective,
  search_space,
  pruner: :median,
  pruner_opts: %{
    n_startup_trials: 5,     # Trials before pruning
    n_warmup_steps: 10,      # Steps before pruning
    interval_steps: 1        # Check frequency
  }
)
```

### Hyperband
Aggressive early stopping with theoretical guarantees:

```elixir
result = Scout.Easy.optimize(
  objective_with_resource,
  search_space,
  pruner: :hyperband,
  pruner_opts: %{
    min_resource: 1,      # Minimum epochs
    max_resource: 100,    # Maximum epochs
    reduction_factor: 3   # η parameter
  }
)
```

### Successive Halving
Tournaments between configurations:

```elixir
result = Scout.Easy.optimize(
  objective,
  search_space,
  pruner: :successive_halving,
  pruner_opts: %{
    min_resource: 1,
    reduction_factor: 2,
    min_early_stopping_rate: 0
  }
)
```

### Patient Pruner
Waits for improvement before pruning:

```elixir
result = Scout.Easy.optimize(
  noisy_objective,
  search_space,
  pruner: :patient,
  pruner_opts: %{
    patience: 10,           # Steps without improvement
    min_delta: 0.01        # Minimum improvement
  }
)
```

## Optimization Strategies

### Warm Starting
Use previous results to bootstrap optimization:

```elixir
# Load previous study
previous = Scout.load_study("phase1")
best_trials = Scout.get_best_trials(previous, n: 10)

# Continue with refined search
result = Scout.Easy.optimize(
  objective,
  refined_search_space,
  sampler: :tpe,
  sampler_opts: %{
    prior_trials: best_trials,
    prior_weight: 0.3
  }
)
```

### Multi-Fidelity Optimization
Use cheap approximations to guide search:

```elixir
def multi_fidelity_objective(params, fidelity \\ :high) do
  case fidelity do
    :low -> 
      # Quick approximation (e.g., fewer epochs)
      quick_evaluate(params, epochs: 5)
    
    :medium ->
      # Better approximation
      evaluate(params, epochs: 20)
      
    :high ->
      # Full evaluation
      full_evaluate(params, epochs: 100)
  end
end

# Optimize with increasing fidelity
result = Scout.Easy.optimize(
  fn params ->
    # Start with low fidelity
    if trial_number < 50 do
      multi_fidelity_objective(params, :low)
    elsif trial_number < 100 do
      multi_fidelity_objective(params, :medium)
    else
      multi_fidelity_objective(params, :high)
    end
  end,
  search_space,
  n_trials: 150
)
```

### Constraint Handling
Handle constraints in the optimization:

```elixir
result = Scout.Easy.optimize(
  fn params ->
    # Check constraints
    if params.n_parameters * params.hidden_size > 1_000_000 do
      # Model too large - return poor score
      Float.min()
    else
      # Normal evaluation
      evaluate_model(params)
    end
  end,
  search_space,
  n_trials: 100
)
```

## Performance Tips

### 1. Choose the Right Sampler
- **TPE**: General purpose, handles all parameter types
- **CMA-ES**: Continuous parameters, correlated
- **Grid**: Small discrete spaces
- **Random**: High dimensions, baseline
- **NSGA-II**: Multiple objectives

### 2. Set Appropriate Parallelism
```elixir
# CPU-bound tasks
parallelism: System.schedulers_online()

# GPU training (usually sequential)
parallelism: 1

# Distributed cluster
parallelism: Node.list() |> length() |> Kernel.*(4)
```

### 3. Use Pruning Wisely
- **Stable metrics**: Aggressive pruning (Hyperband)
- **Noisy metrics**: Patient pruning
- **Progressive training**: Median or percentile
- **Expensive evaluation**: Any pruning helps

### 4. Design Good Search Spaces
- Use log-scale for learning rates
- Limit ranges based on domain knowledge
- Use conditional parameters to reduce space
- Start broad, then refine

## Visualization and Analysis

Scout's dashboard provides real-time insights:
- **Optimization History**: Track progress over time
- **Parameter Importance**: See which parameters matter
- **Parallel Coordinates**: Visualize high-dimensional relationships
- **Intermediate Values**: Monitor pruning decisions

## Next Steps

- Explore [Study Management](study-management.md) for organizing experiments
- Learn about [Dashboard Features](../dashboard/overview.md)
- Review [Sampler API](../api/samplers.md) for detailed configuration
- See [Benchmarks](../benchmarks/optuna-comparison.md) for performance comparisons