#!/usr/bin/env elixir

# This is how you'd actually use Scout in production, just like Optuna

# In Python with Optuna:
# import optuna
# 
# def objective(trial):
#     x = trial.suggest_float('x', -10, 10)
#     y = trial.suggest_float('y', -10, 10)
#     return (x - 2)**2 + (y + 5)**2
#
# study = optuna.create_study(direction='minimize')
# study.optimize(objective, n_trials=100)
# print(study.best_params)

# In Elixir with Scout - using the Easy API:
result = Scout.Easy.optimize(
  fn params -> 
    x = params.x
    y = params.y
    (x - 2) ** 2 + (y + 5) ** 2
  end,
  %{
    x: {:uniform, -10, 10},
    y: {:uniform, -10, 10}
  },
  n_trials: 100,
  direction: :minimize
)

IO.puts "Best value: #{result.best_value}"
IO.puts "Best params: #{inspect(result.best_params)}"