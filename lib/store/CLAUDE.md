# lib/scout/store/ - Persistence Layer

## Overview
Ecto-based persistence for studies, trials, and observations.

## Schemas
- `study.ex` - Study configuration and state
- `trial.ex` - Individual trial records with parameters and results
- `observation.ex` - Intermediate observations during trial execution

## Key Features
- PostgreSQL backend for durability
- Automatic timestamping
- Status tracking (running, paused, completed)
- JSON storage for flexible parameter/result schemas

## Database Operations
- All CRUD operations through Ecto changesets
- Transactions for consistency
- Efficient queries for best trials
- Support for concurrent updates

## Migration Management
Migrations in `priv/repo/migrations/`:
- Study table with status, config, timestamps
- Trial table with parameters, results, state
- Observation table for iterative metrics

## Usage
```elixir
# Create study
{:ok, study} = Store.create_study(attrs)

# Record trial
{:ok, trial} = Store.create_trial(study_id, params)

# Update trial result
{:ok, trial} = Store.update_trial_result(trial_id, result)
```