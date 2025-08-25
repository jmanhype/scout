# lib/scout/ - Core Scout Components

## Overview
Core optimization and study management components.

## Key Files
- `application.ex` - OTP application and supervision tree
- `study_runner.ex` - Main study execution orchestrator
- `study.ex` - Study configuration and state management
- `trial.ex` - Individual trial representation
- `observation.ex` - Trial observations/metrics tracking

## Subdirectories
- `executor/` - Execution strategies (local, Oban/distributed)
- `sampler/` - Sampling algorithms for hyperparameter search
- `pruner/` - Early stopping and pruning strategies
- `store/` - Persistence layer with Ecto schemas
- `util/` - Utility functions and helpers

## Execution Flow
1. Study created with configuration
2. StudyRunner orchestrates trial generation
3. Executor handles trial execution (local or distributed)
4. Sampler suggests hyperparameters
5. Pruner decides early stopping
6. Store persists all data
7. Telemetry emits events throughout