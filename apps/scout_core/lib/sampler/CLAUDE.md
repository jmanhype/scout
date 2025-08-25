# lib/scout/sampler/ - Sampling Algorithms

## Overview
Algorithms for suggesting hyperparameter values during optimization.

## Available Samplers
- `random.ex` - Random sampling from search space
- `grid.ex` - Grid search over discretized space
- `bandit.ex` - Multi-armed bandit with UCB1 for exploration/exploitation

## Interface
Each sampler implements:
```elixir
def suggest(study, trial_index) do
  # Returns suggested hyperparameters
end
```

## Bandit Sampler
- Uses Upper Confidence Bound (UCB1) algorithm
- Balances exploration vs exploitation
- Tracks arm statistics for adaptive sampling
- Good for discrete/categorical hyperparameters

## Future Samplers (TODO)
- TPE (Tree-structured Parzen Estimator) with KDE EI
- Bayesian optimization
- Population-based training