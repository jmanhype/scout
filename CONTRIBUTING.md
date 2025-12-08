# Contributing to Scout

Thank you for your interest in contributing to Scout! This document provides guidelines and instructions for contributing.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [How to Contribute](#how-to-contribute)
- [Pull Request Process](#pull-request-process)
- [Coding Standards](#coding-standards)
- [Testing Guidelines](#testing-guidelines)
- [Documentation](#documentation)

## Code of Conduct

This project adheres to a code of conduct that all contributors are expected to follow. Please read [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) before contributing.

## Getting Started

Scout is an Elixir hyperparameter optimization framework with >99% Optuna parity. Before contributing:

1. **Read the documentation**: Familiarize yourself with [README.md](README.md), [GETTING_STARTED.md](GETTING_STARTED.md), and [API_GUIDE.md](API_GUIDE.md)
2. **Explore examples**: Run the examples in `examples/` to understand Scout's capabilities
3. **Review existing issues**: Check [GitHub Issues](https://github.com/jmanhype/scout/issues) for areas that need help

## Development Setup

### Prerequisites

- Elixir 1.14 or later
- Erlang/OTP 25 or later
- PostgreSQL 15+ (optional, for persistence)
- Git

### Local Setup

```bash
# Clone the repository
git clone https://github.com/jmanhype/scout.git
cd scout

# Install dependencies
mix deps.get

# Run tests (uses ETS, no database needed)
mix test

# Optional: Set up PostgreSQL
cp config.sample.exs config/config.exs
# Edit config/config.exs with your database credentials
mix ecto.create && mix ecto.migrate

# Run tests with coverage
mix coveralls

# Run linter
mix credo

# Run static analysis
mix dialyzer
```

### Project Structure

```
scout/
├── apps/
│   ├── scout_core/        # Core optimization library (publishable to Hex)
│   │   ├── lib/scout/     # Main source code
│   │   └── test/          # Test suite
│   └── scout_dashboard/   # Phoenix LiveView dashboard (optional)
├── examples/              # Runnable examples
├── docs/                  # Documentation
└── k8s/                   # Kubernetes deployment manifests
```

## How to Contribute

### Reporting Bugs

Before creating a bug report, please:

1. **Search existing issues** to avoid duplicates
2. **Use the bug report template** (if available)
3. **Include minimal reproduction** - simplified code that reproduces the issue
4. **Provide environment details**:
   - Elixir version (`elixir --version`)
   - Erlang version (`erl -eval 'erlang:display(erlang:system_info(otp_release))' -noshell`)
   - OS and version

### Suggesting Features

Feature requests are welcome! Please:

1. **Check existing feature requests** first
2. **Explain the use case** - why is this feature valuable?
3. **Provide examples** - how would users use this feature?
4. **Consider Optuna parity** - does Optuna have this feature?

### Good First Issues

Look for issues labeled `good first issue` or `help wanted` - these are great entry points for new contributors.

## Pull Request Process

### Before Submitting

1. **Create an issue first** for significant changes (discuss approach before coding)
2. **Fork the repository** and create a branch from `main`
3. **Write tests** for new functionality (aim for 90%+ coverage)
4. **Update documentation** if changing public APIs
5. **Run the full test suite** and ensure it passes
6. **Run linter** and fix any warnings

### PR Checklist

- [ ] Tests added/updated and passing (`mix test`)
- [ ] Documentation updated (if applicable)
- [ ] Code follows project style (`mix credo`)
- [ ] No dialyzer warnings (`mix dialyzer`)
- [ ] Coverage maintained or improved (`mix coveralls`)
- [ ] Commit messages are clear and descriptive
- [ ] CHANGELOG.md updated (for user-facing changes)

### PR Title Format

Use conventional commits format:

- `feat: Add CMA-ES sampler support`
- `fix: Correct TPE sampler EI calculation`
- `docs: Update API guide with pruning examples`
- `test: Add property-based tests for grid sampler`
- `refactor: Simplify study runner initialization`
- `chore: Update dependencies`

### Commit Messages

- Use present tense ("Add feature" not "Added feature")
- Use imperative mood ("Move cursor to..." not "Moves cursor to...")
- Reference issues: "Fix #123: Correct parameter sampling"
- Keep first line under 72 characters

## Coding Standards

### Elixir Style

- Follow the [Elixir Style Guide](https://github.com/christopheradams/elixir_style_guide)
- Use `mix format` before committing
- Run `mix credo` and address suggestions
- Use meaningful variable names
- Add `@doc` and `@spec` for public functions

### Example

```elixir
@doc """
Samples a value from the specified distribution.

## Parameters

- `distribution`: The distribution to sample from (`:uniform`, `:log_uniform`, etc.)
- `bounds`: Tuple of `{min, max}` values
- `rng`: Random number generator state

## Returns

- `{sampled_value, new_rng_state}`

## Examples

    iex> sample({:uniform, 0, 1}, %{seed: 42})
    {0.6784, %{seed: 43}}
"""
@spec sample(distribution(), bounds(), rng()) :: {float(), rng()}
def sample(distribution, bounds, rng) do
  # Implementation
end
```

## Testing Guidelines

### Test Categories

1. **Unit tests**: Test individual functions in isolation
2. **Integration tests**: Test component interactions
3. **Property-based tests**: Use StreamData for randomized testing
4. **Benchmark tests**: Validate performance characteristics

### Writing Tests

```elixir
defmodule Scout.Sampler.TPETest do
  use ExUnit.Case, async: true
  doctest Scout.Sampler.TPE

  describe "next/4" do
    test "samples from prior for first n_startup_trials" do
      # Arrange
      state = Scout.Sampler.TPE.init(search_space, %{n_startup_trials: 10})
      history = []

      # Act
      {params, _new_state} = Scout.Sampler.TPE.next(5, history, state, search_space)

      # Assert
      assert is_map(params)
      assert Map.has_key?(params, :x)
    end
  end
end
```

### Running Tests

```bash
# Run all tests
mix test

# Run specific test file
mix test test/scout/sampler/tpe_test.exs

# Run specific test
mix test test/scout/sampler/tpe_test.exs:42

# Run with coverage
mix coveralls.html
open cover/excoveralls.html
```

## Documentation

### User-Facing Documentation

- **README.md**: Overview and quick start
- **GETTING_STARTED.md**: Installation and tutorials
- **API_GUIDE.md**: Detailed API reference
- **examples/**: Runnable code examples

### Code Documentation

- Add `@moduledoc` for modules
- Add `@doc` for public functions
- Add `@spec` for type specifications
- Include examples in docstrings
- Document parameters, return values, and exceptions

### Generating Docs

```bash
# Generate ExDocs
mix docs

# View locally
open doc/index.html
```

## Release Process

(For maintainers)

1. Update CHANGELOG.md with all changes
2. Bump version in `apps/scout_core/mix.exs`
3. Run full test suite: `mix test && mix dialyzer`
4. Build docs: `mix docs`
5. Create git tag: `git tag v0.x.x`
6. Publish to Hex: `mix hex.publish`
7. Push to GitHub: `git push --tags`

## Questions?

- **General questions**: Open a [GitHub Discussion](https://github.com/jmanhype/scout/discussions)
- **Bug reports**: Open a [GitHub Issue](https://github.com/jmanhype/scout/issues)
- **Security issues**: See [SECURITY.md](SECURITY.md)

## License

By contributing to Scout, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to Scout! Your efforts help make hyperparameter optimization accessible to the Elixir community.
