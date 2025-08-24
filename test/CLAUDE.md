# test/ - Test Suite

## Overview
Comprehensive test coverage for Scout components.

## Test Organization
- Unit tests for individual modules
- Integration tests for end-to-end workflows
- Property-based tests for samplers/pruners
- Database tests with sandboxed transactions

## Running Tests
```bash
# Run all tests
mix test

# Run specific test file
mix test test/scout/sampler/bandit_test.exs

# Run with coverage
mix test --cover

# Run only tagged tests
mix test --only distributed
```

## Test Helpers
- `Scout.DataCase` - Database test helpers with sandbox
- `Scout.TestHelpers` - Common test utilities
- Fixtures for studies, trials, observations

## Key Test Areas
- Sampler algorithms correctness
- Pruner decision logic
- Executor fault tolerance
- Store persistence operations
- Deterministic seeding verification
- Telemetry event emission