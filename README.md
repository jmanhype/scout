# Scout

Hyperparameter optimization library for Elixir. Umbrella project with the core library in `apps/scout_core`.

Implements samplers, pruners, and search-space primitives found in Python's Optuna, running on BEAM for process-level fault isolation and optional multi-node distribution.

## Status

| Metric | Value |
|--------|-------|
| Version | 0.3.0 (umbrella), 0.3.3 (scout_core) |
| Elixir | >= 1.14 |
| Runtime deps (scout_core) | 4 (telemetry, telemetry_metrics, telemetry_poller, jason) |
| Optional deps | 3 (ecto_sql, postgrex, oban -- for Postgres backend) |
| Modules (.ex) | 89 |
| Test files | 31 |
| CI | GitHub Actions -- last run cancelled (Dec 2025) |
| Hex published | No |

## What it does

- Defines a search space, runs trials across that space, records results.
- 23 sampler implementations (TPE variants, CMA-ES, NSGA-II, QMC, GP, Random, Grid).
- 7 pruner implementations (Median, Percentile, Patient, Threshold, Wilcoxon, SuccessiveHalving, Hyperband).
- Storage backends: ETS (default, no database) or Postgres.
- Optional Axon integration for neural-network hyperparameter tuning.
- Optional Phoenix LiveView dashboard for monitoring studies.

## Umbrella layout

```
apps/
  scout_core/       # Core library: samplers, pruners, store, search space
    lib/
      sampler/      # 23 sampler modules
      pruner/       # 7 pruner modules
      store/        # ETS and Postgres adapters
      executor/     # Local, iterative, and Oban-backed executors
      mix/tasks/    # scout.demo, scout.info, scout.study
    benchmark/      # Benchmark scripts (pruner, sampler, scaling)
    test/
```

## Quick start

```bash
git clone https://github.com/jmanhype/scout
cd scout
mix deps.get
cd apps/scout_core
mix test
```

```elixir
Application.ensure_all_started(:scout_core)

result = Scout.Easy.optimize(
  fn params -> train_model(params) end,
  %{learning_rate: {:log_uniform, 1e-5, 1e-1}, n_layers: {:int, 2, 8}},
  n_trials: 100
)
```

## Dependencies (scout_core)

| Dependency | Purpose | Required |
|-----------|---------|----------|
| telemetry | Event emission | Yes |
| telemetry_metrics | Metric definitions | Yes |
| telemetry_poller | Periodic measurements | Yes |
| jason | JSON encoding | Yes |
| ecto_sql | Postgres storage | No |
| postgrex | Postgres driver | No |
| oban | Background job execution | No |

## Limitations

- Not published to Hex.
- CI is not currently passing (last run was cancelled).
- The ">99% Optuna parity" claim in the repo description is not verified by automated regression tests. Parity scripts exist but require manual execution and Python installed alongside.
- Phoenix dashboard code is referenced but lives outside the core library; setup is not documented end-to-end.
- No production deployment evidence.

## License

MIT
