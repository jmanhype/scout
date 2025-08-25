# Scout API Reference

Complete API documentation for the Scout module and its Easy interface.

## Scout.Easy

The simplified API matching Optuna's ease of use.

### optimize/3

Runs hyperparameter optimization with minimal configuration.

```elixir
Scout.Easy.optimize(objective, search_space, options \\ [])
```

**Parameters:**
- `objective` - Function that takes params map and returns a value to optimize
- `search_space` - Map defining parameter distributions
- `options` - Keyword list of options

**Options:**
- `:n_trials` - Number of trials to run (default: 100)
- `:direction` - `:minimize` or `:maximize` (default: `:minimize`)
- `:sampler` - Algorithm to use (default: `:tpe`)
- `:pruner` - Early stopping strategy (default: `nil`)
- `:parallelism` - Number of concurrent trials (default: 1)
- `:dashboard` - Enable web dashboard (default: `false`)
- `:timeout` - Maximum time per trial (default: `:infinity`)
- `:seed` - Random seed for reproducibility

**Returns:**
```elixir
%{
  best_value: float(),
  best_params: map(),
  best_trial: Trial.t(),
  study: Study.t()
}
```

**Example:**
```elixir
result = Scout.Easy.optimize(
  fn params -> params.x ** 2 + params.y ** 2 end,
  %{x: {:uniform, -5, 5}, y: {:uniform, -5, 5}},
  n_trials: 50,
  direction: :minimize
)
```

### create_study/1

Creates a new study with configuration.

```elixir
Scout.Easy.create_study(options \\ [])
```

**Options:**
- `:name` - Study name (default: auto-generated)
- `:direction` - Optimization direction
- `:sampler` - Sampling algorithm
- `:pruner` - Pruning algorithm
- `:storage` - Storage backend

**Returns:** `Study.t()`

### best_params/1

Extracts best parameters from a study or result.

```elixir
Scout.Easy.best_params(study_or_result)
```

**Returns:** `map()` of best parameters

### best_value/1

Gets the best objective value found.

```elixir
Scout.Easy.best_value(study_or_result)
```

**Returns:** `float()` best value

## Scout.Study

Study management and persistence.

### create/1

Creates a new study.

```elixir
Scout.Study.create(options)
```

**Options:**
- `:name` - Unique study identifier
- `:direction` - `:minimize` or `:maximize`
- `:sampler` - Sampler configuration
- `:pruner` - Pruner configuration
- `:user_attrs` - Custom metadata map
- `:distributed` - Enable distributed optimization

**Returns:** `Study.t()`

### optimize/3

Runs optimization on a study.

```elixir
Scout.Study.optimize(study, objective, options)
```

**Parameters:**
- `study` - Study struct
- `objective` - Objective function
- `options` - Optimization options

### get_trials/2

Retrieves trials from a study.

```elixir
Scout.Study.get_trials(study, filters \\ [])
```

**Filters:**
- `:state` - Trial state (`:complete`, `:pruned`, `:failed`)
- `:filter` - Custom filter function

**Returns:** `[Trial.t()]`

### best_trial/1

Gets the best trial from a study.

```elixir
Scout.Study.best_trial(study)
```

**Returns:** `Trial.t()` or `nil`

### load/1

Loads a persisted study.

```elixir
Scout.Study.load(name_or_id)
```

**Returns:** `Study.t()` or raises

### save_to_file/2

Exports study to file.

```elixir
Scout.Study.save_to_file(study, path)
```

## Scout.Trial

Individual trial management.

### suggest_float/3

Suggests a float parameter value.

```elixir
Scout.Trial.suggest_float(trial, name, low, high, options \\ [])
```

**Options:**
- `:log` - Use log-scale sampling (default: `false`)
- `:step` - Discretization step

**Returns:** `float()`

### suggest_int/3

Suggests an integer parameter.

```elixir
Scout.Trial.suggest_int(trial, name, low, high, options \\ [])
```

**Options:**
- `:log` - Use log-scale sampling
- `:step` - Step size

**Returns:** `integer()`

### suggest_categorical/3

Suggests from categorical choices.

```elixir
Scout.Trial.suggest_categorical(trial, name, choices)
```

**Returns:** One of the choices

### report/3

Reports intermediate value for pruning.

```elixir
Scout.Trial.report(trial, value, step)
```

**Returns:** `:continue` or `:prune`

### set_user_attr/3

Adds custom metadata to trial.

```elixir
Scout.Trial.set_user_attr(trial, key, value)
```

## Scout.Sampler

Sampling algorithms configuration.

### TPE

Tree-structured Parzen Estimator.

```elixir
Scout.Sampler.TPE.new(
  n_startup_trials: 10,
  n_ei_candidates: 24,
  gamma: 0.25,
  prior_weight: 1.0,
  multivariate: true
)
```

### CMA-ES

Covariance Matrix Adaptation Evolution Strategy.

```elixir
Scout.Sampler.CMAES.new(
  sigma: 1.0,
  population_size: nil,  # Auto-calculated
  restart_strategy: "ipop"
)
```

### NSGA-II

Non-dominated Sorting Genetic Algorithm II.

```elixir
Scout.Sampler.NSGA2.new(
  population_size: 50,
  mutation_rate: 0.1,
  crossover_rate: 0.9,
  swapping_rate: 0.5
)
```

### Grid

Grid search sampler.

```elixir
Scout.Sampler.Grid.new()
# No configuration needed
```

### Random

Random sampling.

```elixir
Scout.Sampler.Random.new(seed: 42)
```

## Scout.Pruner

Early stopping algorithms.

### Median

Prunes trials below median.

```elixir
Scout.Pruner.Median.new(
  n_startup_trials: 5,
  n_warmup_steps: 10,
  interval_steps: 1
)
```

### Hyperband

Bandit-based pruning.

```elixir
Scout.Pruner.Hyperband.new(
  min_resource: 1,
  max_resource: 100,
  reduction_factor: 3
)
```

### SuccessiveHalving

Halves candidates iteratively.

```elixir
Scout.Pruner.SuccessiveHalving.new(
  min_resource: 1,
  reduction_factor: 2,
  min_early_stopping_rate: 0
)
```

### Patient

Waits for improvement.

```elixir
Scout.Pruner.Patient.new(
  patience: 10,
  min_delta: 0.01
)
```

## Scout.SearchSpace

Search space utilities.

### define/1

Defines a search space.

```elixir
Scout.SearchSpace.define(%{
  x: {:uniform, -5, 5},
  y: {:log_uniform, 0.001, 1},
  z: {:int, 1, 10},
  algorithm: {:choice, ["a", "b", "c"]}
})
```

### sample/2

Samples from search space.

```elixir
Scout.SearchSpace.sample(space, sampler)
```

**Returns:** Map of sampled values

### validate/2

Validates parameters against space.

```elixir
Scout.SearchSpace.validate(params, space)
```

**Returns:** `:ok` or `{:error, reason}`

## Scout.Store

Storage backend management.

### Postgres

PostgreSQL storage adapter.

```elixir
config :scout, Scout.Store,
  adapter: Scout.Store.Postgres,
  database: "scout_db",
  username: "scout",
  password: "secret",
  hostname: "localhost",
  port: 5432
```

### Memory

In-memory storage (non-persistent).

```elixir
config :scout, Scout.Store,
  adapter: Scout.Store.Memory
```

## Error Handling

Scout functions can raise these exceptions:

- `Scout.InvalidParameterError` - Invalid parameter configuration
- `Scout.StudyNotFoundError` - Study doesn't exist
- `Scout.StorageError` - Database/storage issues
- `Scout.TimeoutError` - Trial exceeded timeout
- `Scout.PruneError` - Trial was pruned

## Telemetry Events

Scout emits telemetry events for monitoring:

- `[:scout, :trial, :start]` - Trial started
- `[:scout, :trial, :stop]` - Trial completed
- `[:scout, :trial, :exception]` - Trial failed
- `[:scout, :study, :best]` - New best value found
- `[:scout, :pruner, :prune]` - Trial pruned

Subscribe to events:

```elixir
:telemetry.attach(
  "scout-handler",
  [:scout, :trial, :stop],
  fn _event, measurements, metadata, _config ->
    IO.puts("Trial #{metadata.trial_id} completed: #{measurements.value}")
  end,
  nil
)
```

## Migration from Optuna

Scout provides compatible APIs for easy migration:

```python
# Optuna (Python)
study = optuna.create_study()
study.optimize(objective, n_trials=100)
```

```elixir
# Scout (Elixir)
study = Scout.Easy.create_study()
Scout.Easy.optimize(objective, %{}, n_trials: 100)
```

## Next Steps

- See [Examples](../getting-started/examples.md) for usage patterns
- Learn about [Study Management](../concepts/study-management.md)
- Explore [Samplers](samplers.md) in detail
- Review [Pruners](pruners.md) documentation