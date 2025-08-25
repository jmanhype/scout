# Study Management

Learn how to organize, persist, and analyze optimization experiments with Scout's study management system.

## What is a Study?

A **Study** is a collection of trials working toward a common optimization goal. It includes:
- Configuration (search space, objective, sampler)
- Trial history (parameters tested and results)
- Best values and parameters found
- Metadata and attributes

## Creating Studies

### Basic Study Creation

```elixir
# Create a study with explicit configuration
study = Scout.Study.create(
  name: "model_optimization_v2",
  direction: :maximize,
  sampler: :tpe,
  pruner: :median,
  storage: :postgres  # or :memory for ephemeral
)

# Run optimization on the study
Scout.Study.optimize(study, objective, n_trials: 100)
```

### Study with Database Persistence

```elixir
# Configure PostgreSQL storage
Application.put_env(:scout, :storage, %{
  adapter: Scout.Store.Postgres,
  database: "scout_experiments",
  hostname: "localhost",
  username: "scout_user",
  password: "secure_password"
})

# Studies are now automatically persisted
study = Scout.Study.create(name: "persistent_study")

# Can be loaded later
study = Scout.Study.load("persistent_study")
```

## Managing Multiple Studies

### Study Organization

```elixir
# Create studies for different experiments
studies = %{
  baseline: Scout.Study.create(name: "baseline_model"),
  improved: Scout.Study.create(name: "improved_architecture"),
  ensemble: Scout.Study.create(name: "ensemble_approach")
}

# Run experiments in parallel
tasks = for {key, study} <- studies do
  Task.async(fn ->
    {key, Scout.Study.optimize(study, objectives[key], n_trials: 50)}
  end)
end

results = Task.await_many(tasks, :timer.minutes(30))
```

### Study Comparison

```elixir
# Compare multiple studies
defmodule StudyComparison do
  def compare(study_names) do
    studies = Enum.map(study_names, &Scout.Study.load/1)
    
    comparison = %{
      best_values: Enum.map(studies, &Scout.Study.best_value/1),
      best_params: Enum.map(studies, &Scout.Study.best_params/1),
      n_trials: Enum.map(studies, &Scout.Study.trial_count/1),
      convergence_speed: Enum.map(studies, &analyze_convergence/1)
    }
    
    generate_comparison_report(comparison)
  end
end
```

## Trial Management

### Accessing Trial Data

```elixir
# Get all trials from a study
trials = Scout.Study.get_trials(study)

# Filter trials
completed_trials = Scout.Study.get_trials(study, state: :complete)
pruned_trials = Scout.Study.get_trials(study, state: :pruned)
failed_trials = Scout.Study.get_trials(study, state: :failed)

# Get best trials
top_10 = Scout.Study.get_best_trials(study, n: 10)

# Get trials with constraints
good_trials = Scout.Study.get_trials(study, 
  filter: fn trial -> trial.value > 0.9 end
)
```

### Trial Analysis

```elixir
# Analyze trial distribution
defmodule TrialAnalysis do
  def analyze(study) do
    trials = Scout.Study.get_trials(study, state: :complete)
    
    %{
      total: length(trials),
      mean_value: Statistics.mean(trials |> Enum.map(& &1.value)),
      std_dev: Statistics.stdev(trials |> Enum.map(& &1.value)),
      best_value: Scout.Study.best_value(study),
      convergence_trial: find_convergence_point(trials),
      parameter_ranges: analyze_parameter_ranges(trials)
    }
  end
  
  defp find_convergence_point(trials) do
    # Find when optimization converged
    trials
    |> Enum.with_index()
    |> Enum.find(fn {trial, idx} ->
      remaining = Enum.drop(trials, idx)
      improvement = max_value(remaining) - trial.value
      improvement < 0.01  # Less than 1% improvement
    end)
  end
end
```

## Study Attributes and Metadata

### Setting Attributes

```elixir
# Add metadata to studies
study = Scout.Study.create(
  name: "production_model",
  user_attrs: %{
    team: "ML Platform",
    project: "Recommendation System",
    environment: "staging",
    dataset_version: "2024.1",
    git_commit: "abc123"
  }
)

# Update attributes
Scout.Study.set_attr(study, "status", "running")
Scout.Study.set_attr(study, "best_accuracy", 0.95)
```

### Querying by Attributes

```elixir
# Find studies by attributes
production_studies = Scout.Study.list(
  filter: %{environment: "production"}
)

recent_studies = Scout.Study.list(
  filter: fn study ->
    study.user_attrs["created_at"] > ~U[2024-01-01 00:00:00Z]
  end
)
```

## Study Persistence and Export

### Saving and Loading

```elixir
# Save study to file
Scout.Study.save_to_file(study, "study_backup.scout")

# Load from file
study = Scout.Study.load_from_file("study_backup.scout")

# Export as JSON
json_data = Scout.Study.to_json(study)
File.write!("study_export.json", json_data)

# Export as CSV
csv_data = Scout.Study.to_csv(study)
File.write!("trials.csv", csv_data)
```

### Database Operations

```elixir
# Backup specific study
Scout.Study.backup(study, "backups/#{study.name}_#{Date.utc_today()}.sql")

# Delete old studies
Scout.Study.delete_older_than(~U[2023-01-01 00:00:00Z])

# Archive completed studies
Scout.Study.archive(study, "archived_studies")
```

## Distributed Studies

### Multi-Node Studies

```elixir
# Create distributed study accessible from multiple nodes
study = Scout.Study.create(
  name: "distributed_optimization",
  storage: :postgres,  # Shared database
  distributed: true
)

# On worker nodes
Node.connect(:"coordinator@host")
study = Scout.Study.load("distributed_optimization")

# Each node can contribute trials
Scout.Study.optimize(study, objective, n_trials: 10)
```

### Study Synchronization

```elixir
# Sync studies across environments
defmodule StudySync do
  def sync_to_production(study_name) do
    dev_study = Scout.Study.load(study_name, env: :development)
    
    prod_study = Scout.Study.create(
      name: "#{study_name}_prod",
      env: :production
    )
    
    # Copy best trials
    best_trials = Scout.Study.get_best_trials(dev_study, n: 20)
    Scout.Study.add_trials(prod_study, best_trials)
    
    prod_study
  end
end
```

## Study Monitoring

### Real-Time Monitoring

```elixir
# Monitor study progress
Scout.Study.monitor(study, fn event ->
  case event do
    {:trial_complete, trial} ->
      Logger.info("Trial #{trial.number} complete: #{trial.value}")
      
    {:new_best, value} ->
      Logger.info("New best value: #{value}")
      send_notification("New best: #{value}")
      
    {:study_complete, summary} ->
      Logger.info("Study complete: #{inspect(summary)}")
  end
end)
```

### Dashboard Integration

```elixir
# Enable dashboard for study
study = Scout.Study.create(
  name: "monitored_study",
  dashboard: true,
  dashboard_port: 4050
)

# Dashboard automatically updates at http://localhost:4050
# Shows:
# - Real-time trial progress
# - Parameter importance
# - Optimization history
# - Parallel coordinates plot
```

## Study Templates

### Reusable Configurations

```elixir
defmodule StudyTemplates do
  def neural_network_template() do
    %{
      search_space: %{
        learning_rate: {:log_uniform, 1e-5, 1e-1},
        batch_size: {:choice, [16, 32, 64, 128]},
        n_layers: {:int, 2, 8},
        dropout: {:uniform, 0, 0.5}
      },
      sampler: :tpe,
      pruner: :median,
      n_trials: 100
    }
  end
  
  def create_from_template(name, template) do
    config = apply(__MODULE__, template, [])
    Scout.Study.create([name: name] ++ config)
  end
end

# Use template
study = StudyTemplates.create_from_template(
  "new_experiment",
  :neural_network_template
)
```

## Study Lifecycle

### Complete Lifecycle Example

```elixir
defmodule StudyLifecycle do
  def run_experiment(config) do
    # 1. Create study
    study = Scout.Study.create(config)
    
    # 2. Run optimization
    Scout.Study.optimize(study, objective, n_trials: 100)
    
    # 3. Analyze results
    analysis = analyze_study(study)
    
    # 4. Save artifacts
    save_results(study, analysis)
    
    # 5. Deploy best model
    if analysis.best_value > threshold do
      deploy_model(study.best_params)
    end
    
    # 6. Archive study
    Scout.Study.archive(study)
    
    analysis
  end
end
```

## Best Practices

### 1. Naming Conventions
```elixir
# Use descriptive, versioned names
"model_type_dataset_v1_2024_01"
"feature_engineering_experiment_3"
"production_hyperopt_2024Q1"
```

### 2. Metadata Tracking
```elixir
# Always track important context
user_attrs: %{
  code_version: git_sha(),
  dataset: dataset_hash(),
  author: current_user(),
  purpose: "Q1 model improvement",
  baseline_score: 0.85
}
```

### 3. Regular Checkpointing
```elixir
# Save progress periodically
Scout.Study.optimize(study, objective, 
  n_trials: 1000,
  callbacks: [
    checkpoint: fn study, trial ->
      if rem(trial.number, 50) == 0 do
        Scout.Study.save_to_file(study, "checkpoint_#{trial.number}.scout")
      end
    end
  ]
)
```

## Next Steps

- Explore the [Dashboard](../dashboard/overview.md) for visual study management
- Learn about [Distributed Optimization](../deployment/distributed.md)
- Review [API Reference](../api/study.md) for complete Study API
- See [Migration Guide](../migration/from-optuna.md) for importing Optuna studies