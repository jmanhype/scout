# 🚀 Getting Started with Scout

Scout is a powerful, distributed hyperparameter optimization framework for Elixir that rivals Optuna with unique BEAM platform advantages.

## 🎯 Quick Start (3 Lines Like Optuna!)

```elixir
# Simple optimization - just like Optuna!
result = Scout.Easy.optimize(
  fn params -> -(params.x**2 + params.y**2) end,  # Maximize negative quadratic
  %{x: {:uniform, -5.0, 5.0}, y: {:uniform, -5.0, 5.0}},
  n_trials: 100
)

IO.puts("Best score: #{result.best_score}")
IO.puts("Best params: #{inspect(result.best_params)}")
```

That's it! Scout will:
- ✅ Auto-start all required infrastructure
- ✅ Use advanced TPE sampler by default
- ✅ Handle errors gracefully with helpful messages
- ✅ Return results in a simple format

## 📊 Real ML Example

```elixir
# Optimize a machine learning pipeline
result = Scout.Easy.optimize(
  fn params ->
    # Your ML training code here
    model = train_model(
      learning_rate: params.learning_rate,
      n_layers: params.n_layers,
      dropout: params.dropout,
      optimizer: params.optimizer
    )
    
    # Return validation accuracy (to maximize)
    validate(model)
  end,
  %{
    learning_rate: {:log_uniform, 1.0e-5, 1.0e-1},
    n_layers: {:int, 2, 8},
    dropout: {:uniform, 0.0, 0.5},
    optimizer: {:choice, ["adam", "sgd", "rmsprop"]}
  },
  n_trials: 50,
  sampler: :tpe,           # Advanced Tree-structured Parzen Estimator
  dashboard: true          # Real-time Phoenix LiveView dashboard!
)

# Dashboard available at: http://localhost:4000
```

## 🧠 Advanced Features

### TPE with Hyperband Pruning

```elixir
result = Scout.Easy.optimize(
  fn params, report_fn ->
    # Progressive ML training with early stopping
    for epoch <- 1..20 do
      accuracy = train_epoch(model, params)
      
      # Report progress for intelligent pruning
      case report_fn.(accuracy, epoch) do
        :continue -> :ok
        :prune -> throw(:pruned)  # Stop early if unpromising
      end
    end
    
    final_accuracy
  end,
  search_space,
  n_trials: 100,
  sampler: :tpe,
  sampler_opts: %{
    gamma: 0.25,           # Top 25% threshold
    multivariate: true,    # Model parameter correlations
    min_obs: 10           # Observations before TPE kicks in
  },
  pruner: :hyperband,
  pruner_opts: %{
    eta: 3,               # Successive halving factor
    max_resource: 20      # Maximum epochs
  },
  parallelism: 4,         # 4 parallel trials
  dashboard: true
)
```

### Multiple Concurrent Studies

```elixir
# Study 1: Neural architecture search
task1 = Task.async(fn ->
  Scout.Easy.optimize(neural_arch_objective, neural_search_space, 
                      study_name: "neural_arch", n_trials: 50)
end)

# Study 2: Traditional ML comparison
task2 = Task.async(fn ->
  Scout.Easy.optimize(traditional_ml_objective, traditional_search_space,
                      study_name: "traditional_ml", n_trials: 30)
end)

# Both studies run in parallel, visible in dashboard
[result1, result2] = Task.await_many([task1, task2], 300_000)
```

## 📚 Parameter Types

Scout supports all major parameter types with validation:

```elixir
search_space = %{
  # Continuous parameters
  learning_rate: {:uniform, 0.001, 0.1},
  weight_decay: {:log_uniform, 1.0e-6, 1.0e-1},  # Log scale
  
  # Integer parameters  
  n_layers: {:int, 1, 10},
  batch_size: {:int, 8, 512},
  
  # Categorical parameters
  optimizer: {:choice, ["adam", "sgd", "rmsprop", "adagrad"]},
  activation: {:choice, ["relu", "tanh", "gelu", "swish"]},
  use_batch_norm: {:choice, [true, false]}
}
```

## 🎛️ Configuration Options

```elixir
result = Scout.Easy.optimize(
  objective_function,
  search_space,
  
  # Basic options
  n_trials: 100,              # Number of trials
  goal: :maximize,            # Or :minimize
  timeout: 3600,              # Timeout in seconds
  
  # Sampler configuration
  sampler: :tpe,              # :random, :tpe, :cmaes
  sampler_opts: %{
    gamma: 0.25,              # TPE quantile threshold
    multivariate: true,       # Enable correlation modeling
    n_candidates: 24          # Candidates per iteration
  },
  
  # Pruning configuration
  pruner: :hyperband,         # :none, :hyperband
  pruner_opts: %{
    eta: 3,                   # Reduction factor
    max_resource: 20          # Maximum resource allocation
  },
  
  # Execution configuration
  parallelism: 4,             # Parallel trials
  dashboard: true,            # Phoenix LiveView dashboard
  study_name: "my_study"      # Custom study name
)
```

## 🌐 Real-time Dashboard

Scout includes a Phoenix LiveView dashboard that provides:

- 📈 **Real-time progress tracking** - See trials as they complete
- 🎯 **Best score sparklines** - Convergence visualization
- 📊 **Parameter distribution plots** - Understand search patterns
- ⏹️ **Hyperband bracket visualization** - See pruning in action
- 🔄 **Study management** - Pause/resume/cancel operations

Access at: **http://localhost:4000** (auto-started with `dashboard: true`)

## 🔧 Advanced Usage

### Manual Study Control

```elixir
# Create study without running (like optuna.create_study)
study = Scout.Easy.create_study(
  sampler: :tpe,
  pruner: :hyperband,
  study_name: "manual_study"
)

# Run trials manually
for trial_num <- 1..100 do
  trial = Scout.suggest_trial(study, search_space)
  score = evaluate_params(trial.params)
  Scout.complete_trial(study, trial, score)
  
  if rem(trial_num, 10) == 0 do
    IO.puts("Trial #{trial_num}: Best = #{Scout.best_score(study)}")
  end
end
```

### Error Handling

```elixir
case Scout.Easy.optimize(objective, search_space) do
  %{status: :completed} = result ->
    IO.puts("Success: #{result.best_score}")
    
  %{status: :timeout} = result ->
    IO.puts("Timed out after #{result.duration}ms")
    
  %{status: :error, error: reason} ->
    IO.puts("Failed: #{reason}")
end
```

## 🔄 Migration from Optuna

| Optuna | Scout | Notes |
|--------|--------|-------|
| `optuna.create_study()` | `Scout.Easy.create_study()` | Same interface |
| `study.optimize(obj, n_trials=100)` | `Scout.Easy.optimize(obj, space, n_trials: 100)` | Search space explicit |
| `study.best_params` | `result.best_params` | Results in return value |
| `study.best_value` | `result.best_score` | Same concept |
| `optuna.samplers.TPESampler` | `sampler: :tpe` | Built-in TPE |
| `optuna.pruners.HyperbandPruner` | `pruner: :hyperband` | Built-in Hyperband |

### Example Migration

**Optuna:**
```python
import optuna

study = optuna.create_study()
study.optimize(objective, n_trials=100)
print(f"Best: {study.best_params}")
```

**Scout:**
```elixir
result = Scout.Easy.optimize(objective, search_space, n_trials: 100)
IO.puts("Best: #{inspect(result.best_params)}")
```

## 🚨 Common Issues & Solutions

### "Module not found" errors
```elixir
# Check Scout status
Scout.Startup.status()

# Manually ensure startup
Scout.Startup.ensure_started()
```

### "Invalid parameter specification"
Scout provides helpful validation with suggestions:
```
Parameter 'learning_rate': uniform min (0.1) must be less than max (0.01)
💡 Tip: For uniform parameters, ensure min < max. Example: {:uniform, 0.0, 1.0}
```

### Dashboard not loading
```elixir
# Check if dashboard dependencies are available
Scout.Startup.start_dashboard()
```

## 🎯 Why Choose Scout?

### vs. Optuna
- ✅ **Same algorithms** (TPE, Hyperband) with proven performance
- ✅ **Real-time dashboard** vs. static matplotlib plots  
- ✅ **BEAM fault tolerance** - trials can't crash the study
- ✅ **Native distribution** - multi-node optimization out of the box
- ✅ **Hot code reloading** - update samplers during long optimizations
- ❌ **Steeper learning curve** - requires Elixir knowledge

### vs. Other Elixir Libraries
- ✅ **Production-ready** with Phoenix dashboard and Oban integration
- ✅ **Advanced algorithms** - not just random/grid search
- ✅ **Comprehensive** - matches Optuna's feature set
- ✅ **Well-tested** - proven on complex ML workloads

## 📖 Next Steps

- 📚 **Read the full documentation**: Browse the `docs/` directory
- 🧪 **Try advanced examples**: Check `examples/` directory  
- 🌐 **Explore the dashboard**: Start with `dashboard: true`
- 🚀 **Scale to multiple nodes**: See distributed execution guide
- 💬 **Join the community**: Contribute and ask questions

## 🤝 Getting Help

- 📖 **Documentation**: Full API docs in `docs/`
- 🐛 **Issues**: Report bugs and request features
- 💡 **Examples**: Real-world usage patterns in `examples/`
- 🔧 **Diagnostics**: Use `Scout.Startup.status()` for troubleshooting

Scout makes hyperparameter optimization as easy as Optuna while leveraging the full power of the BEAM platform. Start optimizing! 🚀