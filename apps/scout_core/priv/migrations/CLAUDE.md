# priv/repo/migrations/ - Database Migrations

## Overview
Ecto migrations defining Scout's database schema.

## Schema Design

### Studies Table
- `id` - Unique study identifier (string)
- `status` - Current status (running/paused/completed)
- `config` - JSON study configuration
- `metadata` - Additional study metadata
- `inserted_at` / `updated_at` - Timestamps

### Trials Table
- `id` - Auto-incrementing primary key
- `study_id` - Foreign key to studies
- `index` - Trial number within study
- `parameters` - JSON hyperparameters
- `result` - Objective function result
- `state` - Trial state (running/succeeded/failed/pruned)
- `metadata` - Additional trial data
- `inserted_at` / `updated_at` - Timestamps

### Observations Table
- `id` - Auto-incrementing primary key
- `trial_id` - Foreign key to trials
- `step` - Observation step/iteration
- `value` - Observed metric value
- `metadata` - Additional observation data
- `inserted_at` - Timestamp

## Running Migrations
```bash
mix ecto.create    # Create database
mix ecto.migrate   # Run migrations
mix ecto.rollback  # Rollback last migration
```