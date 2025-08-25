# lib/scout/pruner/ - Pruning Strategies

## Overview
Early stopping algorithms to terminate unpromising trials early.

## Available Pruners
- `successive_halving.ex` - Successive Halving Algorithm (SHA) for aggressive early stopping
- `median.ex` - Prune trials below median performance at checkpoints

## Successive Halving
- Implements SHA with configurable rungs
- Progressively eliminates bottom performers
- Efficient for large search spaces
- Foundation for Hyperband algorithm

## Interface
```elixir
def should_prune?(study, trial, observation) do
  # Returns {:prune, reason} or :continue
end
```

## Usage in Studies
```elixir
%{
  pruner: Scout.Pruner.SuccessiveHalving,
  pruner_options: %{
    min_resource: 1,
    reduction_factor: 3,
    min_early_stopping_rate: 0
  }
}
```

## Future Work
- Hyperband wrapper over SHA
- Patience-based pruning
- Performance curve extrapolation