# Scout API Guide

Comprehensive guide to Scout's architecture, APIs, and internal workings.

## Table of Contents
- [Architecture Overview](#architecture-overview)
- [Public APIs](#public-apis)
- [Core Components](#core-components)
- [Samplers](#samplers)
- [Pruners](#pruners)
- [Storage Adapters](#storage-adapters)
- [Advanced Topics](#advanced-topics)

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     Scout.Easy API                          │
│            (Optuna-compatible interface)                    │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│                  Scout.StudyRunner                          │
│          (Orchestrates trial execution)                     │
└─────┬────────┬────────┬────────┬────────────────────────────┘
      │        │        │        │
   ┌──▼──┐  ┌─▼──┐  ┌──▼──┐  ┌──▼──┐
   │     │  │    │  │     │  │     │
   │Exec │  │Sam │  │Prun │  │Stor │
   │utor │  │pler│  │er   │  │e    │
   │     │  │    │  │     │  │     │
   └─────┘  └────┘  └─────┘  └─────┘
```

### Key Design Principles

1. **Fault Tolerance**: BEAM supervision trees ensure individual trial failures don't crash the study
2. **Pluggable**: Samplers, pruners, and storage are swappable interfaces
3. **Observable**: Telemetry events at every step for monitoring
4. **Distributed**: Oban executor enables multi-node optimization

## Public APIs

### Scout.Easy - Main Entry Point

The recommended API for 99% of use cases. Provides Optuna-compatible interface.

```elixir
Scout.Easy.optimize(objective, search_space, opts)
```

**Parameters:**
- `objective` - Function `(params) -> number` or `(params, report_fn) -> number`
- `search_space` - Map of `%{param_name => distribution}`
- `opts` - Keyword list:
  - `:n_trials` - Number of trials (default: 100)
  - `:direction` - `:minimize` or `:maximize` (default: `:minimize`)
  - `:sampler` - Sampler to use (default: `:random`)
  - `:pruner` - Pruner to use (default: `nil`)
  - `:seed` - Random seed for reproducibility
  - `:parallelism` - Number of parallel workers (default: 1)
  - `:timeout` - Timeout in milliseconds (default: `:infinity`)
  - `:study_name` - Study identifier for resuming

**Returns:**
Map with:
- `:best_value` - Best objective value found
- `:best_params` - Parameters that achieved best value
- `:best_trial` - Full trial details
- `:n_trials` - Number of trials completed
- `:study_name` - Study identifier
- `:storage_mode` - `:ets` or `:postgres`

**Examples:**

```elixir
# Minimize Rosenbrock function
result = Scout.Easy.optimize(
  fn params ->
    (1 - params.x) ** 2 + 100 * (params.y - params.x ** 2) ** 2
  end,
  %{x: {:uniform, -2, 2}, y: {:uniform, -1, 3}},
  n_trials: 100,
  sampler: :tpe,
  seed: 42
)

# Maximize with pruning
result = Scout.Easy.optimize(
  fn params, report_fn ->
    model = train_model(params)

    for epoch <- 1..10 do
      loss = evaluate_epoch(model, epoch)
      case report_fn.(loss, epoch) do
        :continue -> :ok
        :prune -> throw(:early_stop)
      end
    end

    final_accuracy(model)
  end,
  %{
    learning_rate: {:log_uniform, 1e-5, 1e-1},
    n_layers: {:int, 2, 8}
  },
  direction: :maximize,
  pruner: :hyperband,
  parallelism: 4
)
```

### Scout - Low-Level API

For advanced users who need fine control:

```elixir
# Create study struct
study = %Scout.Study{
  id: "advanced_study",
  goal: :minimize,
  max_trials: 100,
  search_space: fn _ix -> search_space_map end,
  objective: objective_fn,
  sampler: Scout.Sampler.TPE,
  sampler_opts: %{seed: 42},
  pruner: Scout.Pruner.MedianPruner,
  pruner_opts: %{}
}

# Run study
{:ok, result} = Scout.run(study)
```

## Core Components

### Scout.Study

Struct defining an optimization study:

```elixir
%Scout.Study{
  id: String.t(),              # Unique study identifier
  goal: :minimize | :maximize, # Optimization direction
  max_trials: integer(),       # Number of trials to run
  parallelism: integer(),      # Parallel workers (default: 1)
  search_space: function(),    # fn(trial_index) -> param_space
  objective: function(),       # fn(params) -> score
  sampler: module(),           # Sampler module
  sampler_opts: map(),         # Sampler configuration
  pruner: module() | nil,      # Pruner module (optional)
  pruner_opts: map(),          # Pruner configuration
  seed: integer(),             # Random seed
  metadata: map()              # Custom metadata
}
```

### Scout.Trial

Represents a single optimization trial:

```elixir
%Scout.Trial{
  id: String.t(),              # Unique trial ID
  study_id: String.t(),        # Parent study ID
  params: map(),               # Suggested parameters
  value: number() | nil,       # Objective value (nil if failed)
  state: :running | :complete | :failed | :pruned,
  started_at: DateTime.t(),
  completed_at: DateTime.t() | nil
}
```

### Scout.StudyRunner

Main orchestrator that:
1. Generates trials using sampler
2. Executes objectives via executor
3. Collects results
4. Applies pruning decisions
5. Returns best trial

**Not directly called** - used internally by `Scout.run/1`.

## Samplers

Samplers suggest hyperparameters based on historical trials.

### Base Behavior

All samplers implement:

```elixir
@callback init(search_space, opts) :: sampler_state
@callback next(trial_index, history, sampler_state, search_space) ::
  {params, new_state}
```

### Available Samplers

#### Random Sampler (`:random`)

```elixir
Scout.Sampler.RandomSearch
```

- **Algorithm**: Pure random sampling
- **Use case**: Baseline comparisons, very large spaces
- **Pros**: Simple, unbiased, parallelizable
- **Cons**: Doesn't learn from history

**Configuration:**
```elixir
sampler_opts: %{seed: 42}
```

#### TPE (`:tpe`) - **Recommended**

```elixir
Scout.Sampler.TPE
```

- **Algorithm**: Tree-structured Parzen Estimator (Optuna default)
- **Use case**: Most hyperparameter optimization problems
- **Pros**: Learns from history, handles mixed spaces
- **Cons**: Slower than random for very high dimensions (>50)

**Configuration:**
```elixir
sampler_opts: %{
  seed: 42,
  n_startup_trials: 10,  # Random trials before TPE
  n_ei_candidates: 24    # Candidates for EI calculation
}
```

**How it works:**
1. Models good/bad trials as separate distributions
2. Samples from "good" distribution
3. Selects parameters with highest Expected Improvement

#### Grid Sampler (`:grid`)

```elixir
Scout.Sampler.Grid
```

- **Algorithm**: Exhaustive grid search
- **Use case**: Small discrete spaces, reproducible experiments
- **Pros**: Guaranteed coverage, deterministic
- **Cons**: Exponential growth, not suitable for continuous spaces

**Configuration:**
```elixir
search_space: %{
  learning_rate: {:choice, [1e-4, 1e-3, 1e-2]},
  batch_size: {:choice, [16, 32, 64]}
}
# Evaluates all 3 × 3 = 9 combinations
```

#### CMA-ES (`:cmaes`)

```elixir
Scout.Sampler.CmaEs
```

- **Algorithm**: Covariance Matrix Adaptation Evolution Strategy
- **Use case**: Continuous optimization, local refinement
- **Pros**: State-of-the-art for continuous spaces
- **Cons**: Doesn't handle discrete/categorical well

**Configuration:**
```elixir
sampler_opts: %{
  seed: 42,
  sigma: 0.3,           # Initial step size
  population_size: 10   # Population per generation
}
```

#### NSGA-II (`:nsga2`)

```elixir
Scout.Sampler.NSGA2
```

- **Algorithm**: Non-dominated Sorting Genetic Algorithm
- **Use case**: Multi-objective optimization (accuracy vs latency)
- **Pros**: Finds Pareto front
- **Cons**: Slower than single-objective samplers

**Configuration:**
```elixir
objective = fn params ->
  {accuracy, latency} = evaluate(params)
  [-accuracy, latency]  # Return vector of objectives
end

sampler_opts: %{
  population_size: 50,
  crossover_prob: 0.9,
  mutation_prob: 0.1
}
```

**Returns Pareto front** - set of non-dominated solutions.

### Custom Samplers

Implement the `Scout.Sampler` behavior:

```elixir
defmodule MyCustomSampler do
  @behaviour Scout.Sampler

  def init(search_space, opts) do
    # Initialize sampler state
    %{seed: opts[:seed] || 42, history: []}
  end

  def next(trial_index, history, state, space_fun) do
    # Generate parameters based on history
    space = space_fun.(trial_index)
    params = # ... your algorithm ...

    {params, updated_state}
  end
end

# Use it
Scout.Easy.optimize(obj, space, sampler: MyCustomSampler)
```

## Pruners

Pruners decide whether to stop trials early based on intermediate results.

### Base Behavior

```elixir
@callback should_prune?(trial, intermediate_values, all_trials, opts) ::
  boolean()
```

### Available Pruners

#### Median Pruner (`:median`)

```elixir
Scout.Pruner.MedianPruner
```

- **Algorithm**: Stop if intermediate value worse than median
- **Use case**: Aggressive pruning, many cheap trials
- **Saves**: 30-50% compute time

**Configuration:**
```elixir
pruner_opts: %{
  n_startup_trials: 5,    # Don't prune first N trials
  n_warmup_steps: 3       # Don't prune before step N
}
```

#### Percentile Pruner (`:percentile`)

```elixir
Scout.Pruner.PercentilePruner
```

- **Algorithm**: Stop if below percentile threshold
- **Use case**: Conservative pruning
- **Saves**: 20-40% compute time

**Configuration:**
```elixir
pruner_opts: %{
  percentile: 25.0,       # Stop bottom 25%
  n_startup_trials: 5,
  n_warmup_steps: 3
}
```

#### Hyperband (`:hyperband`)

```elixir
Scout.Pruner.Hyperband
```

- **Algorithm**: Adaptive resource allocation
- **Use case**: Deep learning, expensive trials
- **Saves**: 40-70% compute time

**Configuration:**
```elixir
pruner_opts: %{
  max_resource: 81,       # Maximum epochs/iterations
  reduction_factor: 3     # Keeps 1/3 of trials per rung
}
```

**How it works:**
1. Divides trials into "rungs" (epochs 3, 9, 27, 81)
2. At each rung, keeps top 1/reduction_factor trials
3. Others are pruned

**Example:** With 81 trials and reduction_factor=3:
- Epoch 3: 81 trials
- Epoch 9: 27 trials (top 1/3)
- Epoch 27: 9 trials (top 1/3 of 27)
- Epoch 81: 3 trials (top 1/3 of 9)

## Storage Adapters

Scout supports pluggable storage backends.

### ETS Adapter (Default)

```elixir
Scout.Store.ETS
```

- **Type**: In-memory, per-node
- **Persistence**: None (data lost on restart)
- **Use case**: Quick experiments, notebooks
- **Performance**: Very fast

**No configuration needed** - works out of the box.

### PostgreSQL Adapter

```elixir
Scout.Store.Postgres
```

- **Type**: Relational database
- **Persistence**: Survives restarts
- **Use case**: Production, distributed optimization
- **Performance**: Fast (indexed queries)

**Configuration:**
```elixir
# config/config.exs
config :scout_core, Scout.Repo,
  database: "scout_db",
  username: "postgres",
  password: "postgres",
  hostname: "localhost"

# Or via environment variable
export DATABASE_URL="postgres://user:pass@localhost/scout_db"
```

**Migrations:**
```bash
mix ecto.create
mix ecto.migrate
```

**Scout auto-detects** PostgreSQL and switches from ETS.

### Custom Adapters

Implement `Scout.Store.Adapter` behavior:

```elixir
defmodule MyAdapter do
  @behaviour Scout.Store.Adapter

  def create_study(study) do
    # Persist study
    {:ok, study}
  end

  def get_study(study_id) do
    # Fetch study
    {:ok, study}
  end

  def create_trial(trial) do
    # Persist trial
    {:ok, trial}
  end

  # ... implement all callbacks ...
end
```

## Advanced Topics

### Distributed Optimization

Using Oban executor for multi-node optimization:

```elixir
# config/config.exs
config :scout_core,
  executor: Scout.Executor.Oban

# Connect nodes
Node.connect(:"worker1@host1")
Node.connect(:"worker2@host2")

# Optimize (trials distributed across nodes)
result = Scout.Easy.optimize(obj, space,
  parallelism: 20,  # 20 workers across cluster
  n_trials: 1000
)
```

### Telemetry Integration

Scout emits telemetry events for monitoring:

```elixir
:telemetry.attach_many(
  "scout-handler",
  [
    [:scout, :trial, :start],
    [:scout, :trial, :stop],
    [:scout, :trial, :exception]
  ],
  &MyApp.Telemetry.handle_event/4,
  nil
)

def handle_event([:scout, :trial, :stop], measurements, metadata, _config) do
  IO.puts("Trial #{metadata.trial_id} completed in #{measurements.duration}ms")
  IO.puts("Value: #{metadata.value}")
end
```

**Available events:**
- `[:scout, :study, :start]`
- `[:scout, :study, :stop]`
- `[:scout, :trial, :start]`
- `[:scout, :trial, :stop]`
- `[:scout, :trial, :exception]`
- `[:scout, :trial, :pruned]`

### Conditional Search Spaces

Search space can depend on previous parameters:

```elixir
search_space = fn trial_index ->
  # Different space for different trial phases
  if trial_index < 10 do
    %{x: {:uniform, -10, 10}}  # Exploration
  else
    %{x: {:uniform, -1, 1}}    # Exploitation
  end
end

# Or conditional on other parameters
objective = fn params ->
  # optimizer-specific learning rate ranges
  lr_range = case params.optimizer do
    "adam" -> {:log_uniform, 1e-5, 1e-2}
    "sgd" -> {:log_uniform, 1e-3, 1e-1}
  end

  # ... use lr_range ...
end
```

### Warm Starting

Initialize with prior knowledge:

```elixir
# Load historical trials from previous study
history = load_previous_trials()

# Inject into new study
study = %Scout.Study{
  # ... normal config ...
  metadata: %{warm_start_trials: history}
}

{:ok, result} = Scout.run(study)
```

TPE sampler will consider warm-start trials when suggesting parameters.

### Constraints

Add parameter constraints:

```elixir
objective = fn params ->
  # Reject invalid combinations
  if params.min_child_weight > params.max_depth do
    1_000_000  # Large penalty
  else
    actual_objective(params)
  end
end
```

Or use explicit constraints (experimental):

```elixir
constraints = fn params ->
  params.x + params.y <= 10 and
  params.x >= params.y
end

# Sampler respects constraints when sampling
```

## Error Handling

### Objective Function Failures

```elixir
objective = fn params ->
  try do
    train_model(params)
  rescue
    e ->
      Logger.error("Trial failed: #{inspect(e)}")
      :infinity  # Or return large penalty
  end
end
```

Scout marks trial as `:failed` but continues optimization.

### Study Timeout

```elixir
result = Scout.Easy.optimize(obj, space,
  timeout: 600_000  # 10 minutes
)

case result.status do
  :completed -> IO.puts("Success!")
  :error -> IO.puts("Timed out: #{result.error}")
end
```

### Storage Errors

PostgreSQL connection issues are handled gracefully:

```elixir
# Falls back to ETS if PostgreSQL unavailable
Scout.Easy.optimize(obj, space, n_trials: 100)
# => Uses ETS, logs warning
```

## Performance Tips

1. **Use TPE for <50 dimensions**, random for >50
2. **Enable pruning** for expensive objectives (saves 30-70%)
3. **Parallel optimization**: Set `parallelism: N` for N cores
4. **PostgreSQL for long studies** (hours/days)
5. **Batch trials**: Run 10-20 random trials before TPE kicks in
6. **Profile objectives**: 90% of time is in objective function

## See Also

- [Getting Started](GETTING_STARTED.md) - Quick start guide
- [Benchmark Results](BENCHMARK_RESULTS.md) - Performance validation
- [Deployment Guide](DEPLOYMENT.md) - Production deployment

---

**Questions?** Open an issue on [GitHub](https://github.com/jmanhype/scout/issues).
