# Scout Benchmark Infrastructure

Benchmarking framework for Scout hyperparameter optimization performance validation.

## Quick Start

```bash
# Run infrastructure demonstration
mix run benchmark/run.exs

# Test infrastructure components
mix run benchmark/test_infrastructure.exs
```

## Available Components

### Utilities (`benchmark/util.exs`)

Common utilities and test functions for benchmarking:

**Test Functions:**
- `Benchmark.Util.sphere/1` - Simple unimodal function
- `Benchmark.Util.rosenbrock/1` - Banana function with narrow valley
- `Benchmark.Util.rastrigin/1` - Highly multimodal function
- `Benchmark.Util.ackley/1` - Multimodal with flat outer region

All test functions accept both map and list parameters:
```elixir
Benchmark.Util.sphere(%{x1: 1.0, x2: 1.0})  # => 2.0
Benchmark.Util.sphere([1.0, 1.0])           # => 2.0
```

**Helper Functions:**
- `continuous_space(dimensions, min, max)` - Generate search space
- `benchee_config()` - Standard Benchee configuration
- `run_optimization(objective, space, opts)` - Run Scout optimization
- `env_info()` - Get environment information
- `print_env_info()` - Print environment details

### Runner Template (`benchmark/run.exs`)

Demonstration benchmark showing:
- Environment information printing
- Search space creation
- Simple Benchee integration
- Scout optimization runs

Use this as a template for creating specific benchmark suites.

## Creating Custom Benchmarks

Example benchmark file:

```elixir
Code.require_file("util.exs", __DIR__)
alias Benchmark.Util

# Print environment
Util.print_env_info()

# Define search space
space = Util.continuous_space(5, -5, 5)

# Run benchmark
Benchee.run(
  %{
    "Rastrigin 5D (Random)" => fn ->
      Util.run_optimization(
        &Util.rastrigin/1,
        space,
        n_trials: 100,
        sampler: :random
      )
    end,
    "Rastrigin 5D (TPE)" => fn ->
      Util.run_optimization(
        &Util.rastrigin/1,
        space,
        n_trials: 100,
        sampler: :tpe
      )
    end
  },
  Util.benchee_config()
)
```

## Planned Benchmark Suites

These will be implemented in subsequent tasks:

1. **sampler_comparison.exs** - Compare sampler performance
   - Random vs TPE vs Grid vs Bandit
   - Various test functions
   - Different dimensionalities

2. **pruner_effectiveness.exs** - Validate pruner efficiency
   - Successive Halving, Hyperband, Median, Percentile
   - Measure trials saved vs quality loss
   - Timing comparisons

3. **scaling.exs** - Test scaling and parallelism
   - Dimension scaling (2D → 20D)
   - Parallel execution (1, 2, 4, 8 workers)
   - Memory usage profiling

## Environment Information

All benchmarks automatically capture:
- Elixir version
- OTP version
- Scout version
- CPU schedulers (total and online)

## Dependencies

- **Benchee** (~> 1.1) - Benchmarking framework
  - Provides statistical analysis
  - Memory tracking
  - Console formatting with extended statistics

## Configuration

Standard Benchee configuration in `benchee_config()`:
- Warmup: 2 seconds
- Time: 5 seconds
- Memory time: 2 seconds
- Extended statistics enabled

Customize per-benchmark as needed.

## Notes

- All benchmarks use Scout's ETS storage (ephemeral, fast)
- Results are deterministic when using fixed seeds
- Benchmark files are `.exs` scripts (not compiled)
- Use `Code.require_file` to load utilities

## Future Work

- Add visualization/plotting support
- Create benchmark result comparison tools
- Add regression detection
- Integrate with CI for performance monitoring
