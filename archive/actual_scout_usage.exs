#!/usr/bin/env elixir

# ACTUAL SCOUT USAGE - Using Scout as it REALLY exists
# Not creating anything, just using what's there

IO.puts("""
🔬 REAL DOGFOODING: Using Scout AS IT ACTUALLY IS
================================================
I'm an Optuna user trying Scout for the first time.
Let me try to do what I'd do in Optuna...
""")

# First, let me check what Scout actually provides
Code.require_file("lib/scout.ex")
Code.require_file("lib/scout/study.ex") 
Code.require_file("lib/scout/study_runner.ex")
Code.require_file("lib/scout/sampler.ex")
Code.require_file("lib/scout/sampler/random_search.ex")
Code.require_file("lib/scout/sampler/grid.ex")
Code.require_file("lib/scout/sampler/bandit.ex")
Code.require_file("lib/scout/search_space.ex")
Code.require_file("lib/scout/trial.ex")
Code.require_file("lib/scout/store.ex")
Code.require_file("lib/scout/store/ets.ex")
Code.require_file("lib/scout/executor/local.ex")

# Initialize Scout's ETS store
Scout.Store.ETS.start_link([])

IO.puts("\n1️⃣ TRYING OPTUNA'S BASIC EXAMPLE WITH SCOUT")
IO.puts("Optuna: study.optimize(objective, n_trials=100)")
IO.puts("Scout: ???\n")

# Scout's actual API based on the test file
study = %{
  id: "my_optimization",
  goal: :minimize,
  max_trials: 20,
  parallelism: 1,
  seed: 42,
  sampler: Scout.Sampler.RandomSearch,
  sampler_opts: %{},
  pruner: nil,
  pruner_opts: %{},
  
  # This is VERY different from Optuna - search space is separate
  search_space: fn _trial_index ->
    %{
      x: {:uniform, -5.0, 5.0},
      y: {:uniform, -5.0, 5.0}
    }
  end,
  
  # Objective takes params, not trial
  objective: fn params ->
    x = params.x
    y = params.y
    # Minimize distance from (2, 3)
    (x - 2.0) * (x - 2.0) + (y - 3.0) * (y - 3.0)
  end,
  
  metadata: %{}
}

IO.puts("Running Scout optimization...")
result = Scout.StudyRunner.run(study)

case result do
  {:ok, study_result} ->
    IO.puts("✅ Optimization complete!")
    IO.puts("   Best score: #{inspect(study_result.best_score)}")
    IO.puts("   Best params: #{inspect(study_result.best_params)}")
    IO.puts("   Trials run: #{inspect(study_result.n_trials)}")
    
  {:error, reason} ->
    IO.puts("❌ Failed: #{inspect(reason)}")
    
  other ->
    IO.puts("❓ Got: #{inspect(other)}")
end

IO.puts("\n2️⃣ TRYING ML HYPERPARAMETERS (LIKE OPTUNA)")

# Optuna's mixed parameter types
ml_study = %{
  id: "ml_hyperopt",
  goal: :maximize,
  max_trials: 15,
  parallelism: 1,
  sampler: Scout.Sampler.RandomSearch,
  pruner: nil,
  
  search_space: fn _ix ->
    %{
      learning_rate: {:log_uniform, 1.0e-5, 1.0e-1},
      dropout: {:uniform, 0.0, 0.5},
      batch_size: {:choice, [16, 32, 64, 128, 256]},
      optimizer: {:choice, ["adam", "sgd", "rmsprop"]}
    }
  end,
  
  objective: fn params ->
    # Simulate ML training
    base = 0.85
    
    lr_bonus = if params.learning_rate > 0.001 and params.learning_rate < 0.01 do
      0.05
    else
      -0.02
    end
    
    dropout_bonus = if params.dropout > 0.1 and params.dropout < 0.4 do
      0.03
    else
      -0.01
    end
    
    opt_bonus = case params.optimizer do
      "adam" -> 0.03
      "sgd" -> 0.01
      _ -> 0.02
    end
    
    base + lr_bonus + dropout_bonus + opt_bonus + :rand.uniform() * 0.05
  end
}

IO.puts("Running ML hyperparameter optimization...")
ml_result = Scout.StudyRunner.run(ml_study)

case ml_result do
  {:ok, res} ->
    IO.puts("✅ ML optimization complete!")
    IO.puts("   Best accuracy: #{res.best_score}")
    IO.puts("   Best params: #{inspect(res.best_params)}")
    
  _ ->
    IO.puts("❌ ML optimization failed")
end

IO.puts("\n3️⃣ COMPARING APIs: OPTUNA vs SCOUT")
IO.puts("""

OPTUNA (What I'm used to):
```python
def objective(trial):
    x = trial.suggest_float('x', -5, 5)
    y = trial.suggest_float('y', -5, 5)
    return (x - 2)**2 + (y - 3)**2

study = optuna.create_study(direction='minimize')
study.optimize(objective, n_trials=100)
print(study.best_params)
```

SCOUT (What I have to learn):
```elixir
study = %{
  goal: :minimize,
  max_trials: 100,
  search_space: fn _ ->
    %{x: {:uniform, -5.0, 5.0}, y: {:uniform, -5.0, 5.0}}
  end,
  objective: fn params ->
    (params.x - 2.0) ** 2 + (params.y - 3.0) ** 2
  end,
  # ... more config required ...
}
Scout.StudyRunner.run(study)
```

VERDICT AS A REAL USER:
- Scout is MORE VERBOSE than Optuna
- Scout requires MORE BOILERPLATE
- Scout's API is LESS INTUITIVE
- Search space definition is AWKWARD
- No simple 3-line API like Optuna

BUT Scout has:
- Native parallelism
- Better fault tolerance
- Real-time dashboard potential
- BEAM advantages

MIGRATION DIFFICULTY: HIGH
Scout needs that Scout.Easy wrapper to match Optuna's simplicity!
""")