# Scout v0.3 - Root Directory

## Overview
Scout is a durable, distributed hyperparameter optimization framework for Elixir, designed for LLM and ML model tuning.

## Key Features (v0.3)
- **Durable storage**: Ecto/Postgres integration for persistent trials and studies
- **Distributed execution**: Oban job queue for parallel trial execution
- **Deterministic seeding**: Reproducible results with SHA256-based seed derivation
- **Control plane**: Pause/resume/status operations via CLI
- **Telemetry**: Comprehensive event tracking for monitoring

## Quick Start
```bash
# Setup
cp config.sample.exs config/config.exs
mix deps.get
mix ecto.create
mix ecto.migrate

# Run a study
mix scout.study start my_study.exs --executor oban
mix scout.study status study-id
```

## Architecture
- `lib/scout/` - Core optimization logic
- `lib/scout/executor/` - Execution strategies (local, Oban)
- `lib/scout/sampler/` - Sampling algorithms (Random, Bandit, Grid)
- `lib/scout/pruner/` - Early stopping strategies
- `lib/scout/store/` - Persistence layer
- `priv/repo/` - Database migrations
- `test/` - Test suite

## Dependencies
- Ecto + PostgreSQL for persistence
- Oban for distributed job processing
- Telemetry for observability