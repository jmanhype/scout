# lib/ - Core Application Code

## Overview
Main application logic for Scout hyperparameter optimization framework.

## Structure
- `scout.ex` - Main module and public API
- `scout/` - Core components organized by responsibility
- `mix/tasks/` - Mix tasks for CLI operations

## Key Modules
- `Scout` - Public API facade
- `Scout.Application` - OTP application supervisor
- `Scout.StudyRunner` - Study orchestration logic
- Various domain modules for optimization logic