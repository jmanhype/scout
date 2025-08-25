# lib/scout/util/ - Utility Functions

## Overview
Helper functions and utilities used across Scout.

## Key Utilities
- `seeding.ex` - Deterministic seed generation using SHA256
- `telemetry.ex` - Telemetry event helpers and attachments

## Deterministic Seeding
```elixir
# Generates reproducible seed for each trial
seed = Scout.Util.Seeding.trial_seed(study_id, trial_index, base_seed)
```

Uses SHA256 hashing of study_id + trial_index + base_seed to ensure:
- Reproducibility across runs
- Independence between trials
- Deterministic parallelism

## Telemetry Events
Emitted events:
- `[:scout, :study, :start]`
- `[:scout, :study, :stop]`
- `[:scout, :trial, :start]`
- `[:scout, :trial, :stop]`
- `[:scout, :trial, :prune]`
- `[:scout, :trial, :error]`

Used for monitoring, debugging, and building dashboards.