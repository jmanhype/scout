# Scout Quick Start

**Get started in 30 seconds - no database required!**

## Installation

```bash
git clone https://github.com/your-org/scout
cd scout
mix deps.get
```

## Run Your First Optimization

```bash
cd apps/scout_core
mix run ../../quick_start.exs
```

Output:
```
=== Scout Quick Start ===

Finding minimum of f(x,y) = x² + y²
Expected optimum: x=0, y=0, value=0

=== Results ===
Best value: 0.928678
Best x:     0.301208
Best y:     -0.915397

Status: SUCCESS ✓

Scout is working! No database required.
```

## Your First Script

Create `my_optimization.exs`:

```elixir
# Start Scout (uses ETS - no database needed)
Application.ensure_all_started(:scout_core)

# Define your objective function
result = Scout.Easy.optimize(
  fn params ->
    # Your ML training code here
    # Return a score to minimize or maximize
    train_and_evaluate_model(params)
  end,
  %{
    learning_rate: {:log_uniform, 1e-5, 1e-1},
    batch_size: {:choice, [16, 32, 64, 128]},
    dropout: {:uniform, 0.1, 0.5}
  },
  n_trials: 100,
  sampler: :random  # or :tpe, :cmaes, :grid
)

IO.inspect(result.best_params)
IO.puts("Best score: #{result.best_score}")
```

Run it:
```bash
cd apps/scout_core
mix run my_optimization.exs
```

## Available Samplers

```elixir
sampler: :random    # Random search (baseline)
sampler: :tpe       # Tree-structured Parzen Estimator (Bayesian)
sampler: :cmaes     # Covariance Matrix Adaptation
sampler: :grid      # Grid search
```

## Search Space Options

```elixir
%{
  # Continuous uniform
  learning_rate: {:uniform, 0.0001, 0.1},

  # Log-uniform (good for learning rates)
  lr: {:log_uniform, 1e-5, 1e-1},

  # Integer range
  n_layers: {:int, 2, 10},

  # Categorical choice
  optimizer: {:choice, ["adam", "sgd", "rmsprop"]},

  # Log-integer
  hidden_size: {:log_int, 32, 512}
}
```

## Next Steps

- See [BENCHMARK_RESULTS.md](BENCHMARK_RESULTS.md) for performance validation
- See [benchmark/SAMPLER_COMPARISON.md](benchmark/SAMPLER_COMPARISON.md) for sampler selection guide
- See [README.md](README.md) for production deployment

## Optional: Use Postgres for Persistence

If you want persistent storage across runs:

1. Start Postgres
2. Update `config/config.exs`:
   ```elixir
   config :scout_core,
     store_adapter: Scout.Store.Postgres  # Change from ETS
   ```
3. Run: `mix ecto.create && mix ecto.migrate`
4. Now your studies persist across restarts

## No Database? No Problem!

Scout defaults to ETS (in-memory) storage. Perfect for:
- Quick experiments
- Jupyter-style iterative development
- Testing and benchmarking
- Single-machine optimizations

The exact same API works with both storage backends.
