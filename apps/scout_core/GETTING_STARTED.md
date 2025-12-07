# Getting Started with Scout

Scout is a production-ready hyperparameter optimization framework for Elixir, providing >99% feature parity with Optuna.

## Table of Contents
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Core Concepts](#core-concepts)
- [Storage Modes](#storage-modes)
- [Basic Examples](#basic-examples)
- [Advanced Usage](#advanced-usage)
- [Next Steps](#next-steps)

## Installation

Add Scout to your `mix.exs` dependencies:

```elixir
defp deps do
  [
    {:scout, "~> 0.3"}
  ]
end
```

Then install dependencies:

```bash
mix deps.get
```

**That's it!** Scout works out of the box with in-memory ETS storage - no database required.

### Optional: PostgreSQL Persistence

For production use with persistent storage:

```bash
# 1. Set database URL
export DATABASE_URL="postgres://user:pass@localhost/scout_db"

# 2. Create and migrate database
mix ecto.create
mix ecto.migrate
```

Scout automatically detects and uses PostgreSQL when available.

## Quick Start

Here's a complete optimization in 3 lines:

```elixir
# Define objective function
objective = fn params ->
  # Minimize: f(x,y) = (x-2)² + (y-3)²
  (params.x - 2) ** 2 + (params.y - 3) ** 2
end

# Define search space
search_space = %{
  x: {:uniform, -5, 5},
  y: {:uniform, -5, 5}
}

# Optimize!
result = Scout.Easy.optimize(objective, search_space, n_trials: 100)

IO.puts("Best value: #{result.best_value}")
IO.puts("Best params: #{inspect(result.best_params)}")
# => Best params: %{x: 2.01, y: 2.98}
```

## Core Concepts

### 1. Objective Function

The function you want to optimize. It receives a map of parameters and returns a number to minimize or maximize:

```elixir
# Simple objective
fn params -> params.x ** 2 end

# With pruning support (early stopping)
fn params, report_fn ->
  for epoch <- 1..20 do
    loss = train_epoch(model, params)

    # Report intermediate value
    case report_fn.(loss, epoch) do
      :continue -> :ok
      :prune -> throw(:early_stop)  # Stop this trial
    end
  end

  final_loss
end
```

### 2. Search Space

Defines the hyperparameter space to explore:

```elixir
%{
  # Continuous distributions
  learning_rate: {:log_uniform, 1e-5, 1e-1},
  dropout: {:uniform, 0.1, 0.5},

  # Discrete distributions
  n_layers: {:int, 2, 8},
  batch_size: {:choice, [16, 32, 64, 128]},

  # Categorical
  optimizer: {:choice, ["adam", "sgd", "rmsprop"]}
}
```

**Available distributions:**
- `{:uniform, min, max}` - Continuous uniform
- `{:log_uniform, min, max}` - Log-scale uniform
- `{:int, min, max}` - Integer range
- `{:choice, list}` - Categorical choice

### 3. Samplers

Algorithms for suggesting hyperparameters:

```elixir
# Random sampling (baseline)
Scout.Easy.optimize(obj, space, sampler: :random)

# Tree-structured Parzen Estimator (recommended)
Scout.Easy.optimize(obj, space, sampler: :tpe)

# Grid search
Scout.Easy.optimize(obj, space, sampler: :grid)

# CMA-ES (for continuous spaces)
Scout.Easy.optimize(obj, space, sampler: :cmaes)

# Multi-objective NSGA-II
Scout.Easy.optimize(obj, space, sampler: :nsga2)
```

**When to use each:**
- `:random` - Baseline, simple problems
- `:tpe` - **Most problems** (Optuna default)
- `:grid` - Small spaces, exhaustive search
- `:cmaes` - Continuous optimization
- `:nsga2` - Multi-objective optimization

### 4. Pruners

Early stopping for expensive trials:

```elixir
# Median pruner (stop bottom 50%)
Scout.Easy.optimize(obj, space,
  pruner: :median,
  n_trials: 100
)

# Hyperband (aggressive early stopping)
Scout.Easy.optimize(obj, space,
  pruner: :hyperband,
  n_trials: 100
)
```

**Pruners save 30-70% compute time** on deep learning workloads.

## Storage Modes

Scout supports two storage backends:

### ETS (In-Memory) - Default

```elixir
# No configuration needed - just works!
result = Scout.Easy.optimize(obj, space, n_trials: 100)
```

**Pros:**
- Zero setup
- Fast
- Perfect for notebooks and quick experiments

**Cons:**
- Data lost when process exits
- No distributed optimization

### PostgreSQL (Persistent)

```bash
export DATABASE_URL="postgres://localhost/scout_db"
mix ecto.create && mix ecto.migrate
```

```elixir
# Scout auto-detects PostgreSQL
result = Scout.Easy.optimize(obj, space, n_trials: 100)

# Check current mode
Scout.Store.storage_mode()  # => :postgres
```

**Pros:**
- Data survives restarts
- Enable distributed optimization across nodes
- Query historical trials
- Production-ready

**Cons:**
- Requires PostgreSQL setup

## Basic Examples

### Example 1: Minimize Sphere Function

```elixir
# Minimize: f(x) = x₁² + x₂² + x₃²
objective = fn params ->
  params.x1 ** 2 + params.x2 ** 2 + params.x3 ** 2
end

space = %{
  x1: {:uniform, -5, 5},
  x2: {:uniform, -5, 5},
  x3: {:uniform, -5, 5}
}

result = Scout.Easy.optimize(objective, space,
  n_trials: 50,
  sampler: :tpe,
  direction: :minimize
)

# Result should be near 0 at (0, 0, 0)
IO.inspect(result.best_value)   # => ~0.001
IO.inspect(result.best_params)  # => %{x1: 0.01, x2: -0.02, x3: 0.01}
```

### Example 2: Neural Network Hyperparameters

```elixir
objective = fn params ->
  model = build_model(
    layers: params.n_layers,
    neurons: params.neurons,
    dropout: params.dropout
  )

  train_result = train(model,
    learning_rate: params.learning_rate,
    batch_size: params.batch_size,
    optimizer: params.optimizer
  )

  -train_result.accuracy  # Negative because we minimize
end

space = %{
  # Architecture
  n_layers: {:int, 2, 8},
  neurons: {:int, 32, 512},
  dropout: {:uniform, 0.1, 0.5},

  # Training
  learning_rate: {:log_uniform, 1e-5, 1e-1},
  batch_size: {:choice, [16, 32, 64, 128]},
  optimizer: {:choice, ["adam", "sgd", "rmsprop"]}
}

result = Scout.Easy.optimize(objective, space,
  n_trials: 100,
  sampler: :tpe,
  direction: :minimize
)

IO.puts("Best accuracy: #{-result.best_value}")
```

### Example 3: With Pruning (Early Stopping)

```elixir
objective = fn params, report_fn ->
  model = build_model(params)

  # Train with early stopping
  for epoch <- 1..20 do
    loss = train_epoch(model, params.learning_rate)

    # Report to pruner
    case report_fn.(loss, epoch) do
      :continue -> :ok
      :prune ->
        IO.puts("Trial pruned at epoch #{epoch}")
        throw(:early_stop)
    end
  end

  validate(model)
end

result = Scout.Easy.optimize(objective, space,
  n_trials: 100,
  sampler: :tpe,
  pruner: :hyperband  # Aggressive early stopping
)
```

## Advanced Usage

### Parallel Optimization

```elixir
# Run 4 trials in parallel
result = Scout.Easy.optimize(objective, space,
  n_trials: 100,
  parallelism: 4  # 4 concurrent workers
)
```

### Reproducible Results

```elixir
# Fixed seed for reproducibility
result = Scout.Easy.optimize(objective, space,
  n_trials: 100,
  seed: 42
)
```

### Named Studies (Resume Later)

```elixir
# First run
result1 = Scout.Easy.optimize(objective, space,
  study_name: "my_experiment",
  n_trials: 50
)

# Resume later (if using PostgreSQL)
result2 = Scout.Easy.optimize(objective, space,
  study_name: "my_experiment",  # Same name
  n_trials: 50  # 50 more trials
)
```

### Maximize Instead of Minimize

```elixir
# Maximize accuracy
result = Scout.Easy.optimize(objective, space,
  direction: :maximize,  # Default is :minimize
  n_trials: 100
)
```

### Timeout

```elixir
# Stop after 10 minutes
result = Scout.Easy.optimize(objective, space,
  timeout: 600_000  # milliseconds
)
```

## Next Steps

### Learn More

- **[API Guide](API_GUIDE.md)** - Deep dive into APIs and architecture
- **[Benchmark Results](BENCHMARK_RESULTS.md)** - Performance validation
- **[Deployment Guide](DEPLOYMENT.md)** - Production deployment with Docker/K8s

### Examples

Explore `examples/` directory:
- `quick_start.exs` - 3-line minimal example
- `neural_network.exs` - Real ML optimization
- `multi_objective.exs` - Pareto optimization
- `distributed.exs` - Multi-node setup

### Common Patterns

**Pattern 1: Bayesian Optimization**
```elixir
Scout.Easy.optimize(objective, space, sampler: :tpe, n_trials: 100)
```

**Pattern 2: Random Search Baseline**
```elixir
Scout.Easy.optimize(objective, space, sampler: :random, n_trials: 1000)
```

**Pattern 3: Aggressive Pruning**
```elixir
Scout.Easy.optimize(objective, space,
  sampler: :tpe,
  pruner: :hyperband,
  n_trials: 200
)
```

**Pattern 4: Multi-Objective**
```elixir
objective = fn params ->
  {accuracy, latency} = evaluate(params)
  [-accuracy, latency]  # Minimize both (negate accuracy)
end

Scout.Easy.optimize(objective, space, sampler: :nsga2)
```

### Get Help

- **Issues**: [GitHub Issues](https://github.com/jmanhype/scout/issues)
- **Discussions**: Ask questions in GitHub Discussions
- **Examples**: Check `examples/` for working code

---

**You're ready to optimize!** Start with `Scout.Easy.optimize/3` and scale up from there.
