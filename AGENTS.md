# ExecPlans

When writing complex features or significant refactors, use an ExecPlan (as described in `.agent/PLANS.md`) from design to implementation.

ExecPlans are living documents and must be maintained according to `.agent/PLANS.md`. They should be referenced explicitly when starting large tasks.

## Parity Benchmark Notes

Scout ships a dedicated Optuna-style sampler (`apps/scout_core/lib/sampler/tpe_optuna.ex`) used by `scripts/parity_optuna_vs_scout.exs`. Parity on the 2D sphere benchmark (200 trials, seed 123) currently holds with defaults: gamma=min(0.25, sqrt(n)/n), Scott bandwidth *0.5 with floor 1e-3, 64 candidates + ~10% random mix, 1% uniform prior. Re-run the script from repo root (`python3 scripts/parity_optuna_vs_scout.exs`) after sampler changes to confirm parity.
