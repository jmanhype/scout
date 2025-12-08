---
name: Bug Report
about: Report a bug to help us improve Scout
title: '[BUG] '
labels: bug
assignees: ''
---

## Bug Description

A clear and concise description of the bug.

## To Reproduce

Steps to reproduce the behavior:

1. Set up Scout with '...'
2. Run optimization with '...'
3. Observe error '...'

## Minimal Reproduction

Please provide minimal code that reproduces the issue:

```elixir
# Minimal reproduction code here
Application.ensure_all_started(:scout_core)

objective = fn params ->
  # Your objective function
end

search_space = %{
  # Your search space
}

Scout.Easy.optimize(objective, search_space, n_trials: 10)
```

## Expected Behavior

A clear description of what you expected to happen.

## Actual Behavior

What actually happened instead.

## Environment

Please complete the following information:

- Scout version: [e.g., 0.3.1]
- Elixir version: [run `elixir --version`]
- Erlang/OTP version: [from `elixir --version` output]
- Operating System: [e.g., macOS 14.6, Ubuntu 22.04]
- Storage backend: [ETS or PostgreSQL]

## Stack Trace

If applicable, add the full error message and stack trace:

```
[error] ...
```

## Additional Context

Add any other context about the problem here, such as:

- Does this happen consistently or intermittently?
- Have you made any custom modifications to Scout?
- Are there any workarounds you've found?

## Checklist

- [ ] I have searched existing issues to avoid duplicates
- [ ] I have provided a minimal reproduction
- [ ] I have included all environment details
- [ ] I have included the stack trace (if applicable)
