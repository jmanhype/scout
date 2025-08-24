#!/usr/bin/env elixir

IO.puts("🧪 TESTING SCOUT.EASY - OPTUNA-LIKE 3-LINE API")
IO.puts(String.duplicate("=", 50))

# Test 1: Simple quadratic optimization (like Optuna README example)
IO.puts("\nTest 1: Quadratic optimization")
IO.puts("-------------------------------")

result = Scout.Easy.optimize(
  fn params -> 
    :math.pow(params[:x] - 2, 2) + :math.pow(params[:y] - 3, 2)
  end,
  %{
    x: {:uniform, -10, 10},
    y: {:uniform, -10, 10}
  },
  n_trials: 50,
  direction: :minimize
)

IO.puts("Best value: #{result.best_value}")
IO.puts("Best params: x=#{result.best_params[:x]}, y=#{result.best_params[:y]}")
IO.puts("Expected: x≈2, y≈3, value≈0")

# Test 2: ML hyperparameter optimization (like Optuna's SVM example)
IO.puts("\nTest 2: ML Hyperparameter Optimization")
IO.puts("---------------------------------------")

ml_result = Scout.Easy.optimize(
  fn params ->
    # Simulate SVM accuracy based on hyperparameters
    # This mimics what Optuna does in their README
    c_score = 1.0 / (1.0 + abs(params[:C] - 1.0))
    gamma_score = 1.0 / (1.0 + abs(params[:gamma] - 0.001))
    kernel_bonus = if params[:kernel] == "rbf", do: 0.1, else: 0.0
    
    # Return negative for minimization (like negative accuracy)
    -(c_score * gamma_score + kernel_bonus)
  end,
  %{
    C: {:log_uniform, 0.01, 100},
    gamma: {:log_uniform, 0.0001, 1},
    kernel: {:choice, ["rbf", "linear", "poly"]}
  },
  n_trials: 30,
  direction: :minimize
)

IO.puts("Best hyperparameters:")
IO.puts("  C: #{ml_result.best_params[:C]}")
IO.puts("  gamma: #{ml_result.best_params[:gamma]}")
IO.puts("  kernel: #{ml_result.best_params[:kernel]}")
IO.puts("  score: #{-ml_result.best_value}")

# Test 3: Maximization (like Optuna's maximize example)
IO.puts("\nTest 3: Maximization")
IO.puts("--------------------")

max_result = Scout.Easy.optimize(
  fn params ->
    # Rosenbrock function (inverted for maximization)
    a = 1
    b = 100
    term1 = :math.pow(a - params[:x], 2)
    term2 = b * :math.pow(params[:y] - :math.pow(params[:x], 2), 2)
    -(term1 + term2)  # Negative because we want to maximize
  end,
  %{
    x: {:uniform, -5, 5},
    y: {:uniform, -5, 5}
  },
  n_trials: 100,
  direction: :maximize
)

IO.puts("Best value: #{max_result.best_value}")
IO.puts("Best params: x=#{max_result.best_params[:x]}, y=#{max_result.best_params[:y]}")

IO.puts("\n" <> String.duplicate("=", 50))
IO.puts("COMPARISON WITH OPTUNA:")
IO.puts(String.duplicate("=", 50))
IO.puts("""

OPTUNA (Python):
```python
import optuna

def objective(trial):
    x = trial.suggest_uniform('x', -10, 10)
    y = trial.suggest_uniform('y', -10, 10)
    return (x - 2) ** 2 + (y - 3) ** 2

study = optuna.create_study()
study.optimize(objective, n_trials=50)
print(study.best_params)
```

SCOUT (Elixir) with Scout.Easy:
```elixir
result = Scout.Easy.optimize(
  fn params -> 
    :math.pow(params[:x] - 2, 2) + :math.pow(params[:y] - 3, 2)
  end,
  %{x: {:uniform, -10, 10}, y: {:uniform, -10, 10}},
  n_trials: 50
)
IO.inspect(result.best_params)
```

✅ SCOUT NOW MATCHES OPTUNA'S SIMPLICITY!
""")