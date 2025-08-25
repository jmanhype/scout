# lib/mix/tasks/ - CLI Tasks

## Overview
Mix tasks providing CLI interface for Scout operations.

## Available Tasks
- `scout.study` - Main task for study management
  - `start` - Start a new study
  - `status` - Check study status
  - `pause` - Pause running study
  - `resume` - Resume paused study
  - `list` - List all studies

## Usage Examples
```bash
# Start study with Oban executor
mix scout.study start my_study.exs --executor oban

# Check status
mix scout.study status my-study-id

# Pause execution
mix scout.study pause my-study-id

# Resume execution
mix scout.study resume my-study-id

# List all studies
mix scout.study list
```

## Implementation
Tasks interact with Scout.StudyRunner and Scout.Store to:
- Parse study configuration files
- Manage study lifecycle
- Query study/trial status
- Control distributed execution