# Scout v0.3.0 - Coverage Baseline Analysis

**Date**: 2025-12-06
**Status**: Cannot generate coverage report (Postgres required)
**Beads Task**: scout-30a

---

## Executive Summary

Scout requires PostgreSQL for test execution, blocking automated coverage measurement. However, we can perform a structural analysis to identify coverage gaps and prioritize work.

### Key Findings
- **74 source files** across core modules
- **10 test files** (13.5% test-to-source ratio)
- **Major gap**: Limited sampler/pruner test coverage
- **Recommendation**: Start with public API (Scout.Easy) then work through samplers systematically

---

## Source Code Inventory

### By Module Type

| Category | File Count | Files |
|----------|------------|-------|
| **Samplers** | 28 | TPE (7 variants), CMA-ES (2), Grid, Random, Bandit, NSGA-II, MOTPE, GP, QMC, etc. |
| **Pruners** | 7 | Median, Percentile, Hyperband, SuccessiveHalving, Patient, Threshold, Wilcoxon |
| **Stores** | 6 | Adapter, ETS, ETS Hardened, Postgres, + 3 schemas |
| **Executors** | 4 | Base, Local, Oban, Iterative |
| **Utilities** | 5 | RNG, SafeAtoms, Seed, Log |
| **Public API** | 1 | Scout.Easy |
| **Other** | 23 | Study, Trial, SearchSpace, Constraints, Integration, etc. |
| **TOTAL** | 74 | All source files |

### Detailed File List

#### Public API (P0 Priority)
```
lib/easy.ex                           # CRITICAL - main user-facing API
```

#### Samplers (P0 for core, P1 for experimental)
```
lib/sampler.ex                        # Sampler behavior
lib/sampler/random.ex                 # P0 - Baseline sampler
lib/sampler/tpe.ex                    # P0 - Main TPE implementation
lib/sampler/grid.ex                   # P0 - Grid search
lib/sampler/cmaes.ex                  # P0 - CMA-ES
lib/sampler/nsga2.ex                  # P0 - Multi-objective
lib/sampler/motpe.ex                  # P0 - Multi-objective TPE

# TPE Variants (P1 - experimental)
lib/sampler/conditional_tpe.ex
lib/sampler/constant_liar_tpe.ex
lib/sampler/correlated_tpe.ex
lib/sampler/optimized_correlated_tpe.ex
lib/sampler/prior_tpe.ex
lib/sampler/tpe_enhanced.ex
lib/sampler/tpe_fixed.ex
lib/sampler/tpe_integrated.ex
lib/sampler/tpe_multivariate.ex
lib/sampler/warm_start_tpe.ex

# Other Samplers (P1)
lib/sampler/multivar_tpe.ex
lib/sampler/multivariate_tpe.ex
lib/sampler/multivariate_tpe_v2.ex    # V2 experimental (skip in coverage)
lib/sampler/bandit.ex
lib/sampler/cmaes_simple.ex
lib/sampler/gp.ex
lib/sampler/qmc.ex
lib/sampler/random_search.ex
```

#### Pruners (P0)
```
lib/pruner.ex                         # Pruner behavior
lib/pruner/median.ex                  # P0
lib/pruner/percentile.ex              # P0
lib/pruner/hyperband.ex               # P0
lib/pruner/successive_halving.ex      # P0
lib/pruner/patient.ex                 # P1
lib/pruner/threshold.ex               # P1
lib/pruner/wilcoxon.ex                # P1
```

#### Store Adapters (P0)
```
lib/store.ex                          # Store interface
lib/store/adapter.ex                  # Adapter behavior
lib/store/ets.ex                      # P0 - ETS adapter
lib/store/postgres.ex                 # P0 - Postgres adapter
lib/store/ets_hardened.ex             # Experimental (skip in coverage)
lib/store/schemas/study.ex            # P0
lib/store/schemas/trial.ex            # P0
lib/store/schemas/observation.ex      # P0
```

#### Executors (P1)
```
lib/executor.ex                       # Executor behavior
lib/executor/local.ex                 # P0 - Local execution
lib/executor/oban.ex                  # P1 - Distributed execution
lib/executor/iterative.ex             # P1
```

#### Utilities (P1)
```
lib/util/rng.ex                       # P0 - RNG determinism
lib/util/safe_atoms.ex                # P0 - Atom exhaustion protection
lib/util/seed.ex                      # P0 - Seed derivation
lib/util/log.ex                       # P2
```

---

## Test Code Inventory

### Existing Tests (10 files)

```
test/adapter_spec_ets_test.exs                # Store adapter contract tests (ETS)
test/adapter_spec_postgres_test.exs           # Store adapter contract tests (Postgres)
test/end_to_end_test.exs                      # Integration tests
test/executor_contract_test.exs               # Executor contract tests
test/math/kde_test.exs                        # Math utilities (KDE)
test/proof_of_fixes_test.exs                  # Regression tests
test/security_test.exs                        # Security (atom exhaustion)
test/smoke_local_test.exs                     # Smoke tests
test/store/ets_invariants_test.exs            # Store invariants
test/util/rng_test.exs                        # RNG determinism tests
```

### Test Coverage Analysis

| Module | Has Tests? | Notes |
|--------|-----------|-------|
| **Scout.Easy** | ❌ No | **CRITICAL GAP** - main API untested |
| **Samplers (28 files)** | ❌ No | **MAJOR GAP** - no sampler unit tests |
| **Pruners (7 files)** | ❌ No | **MAJOR GAP** - no pruner unit tests |
| **Store adapters** | ✅ Yes | Good (contract + invariant tests) |
| **Executors** | ✅ Partial | Contract tests exist |
| **Util.RNG** | ✅ Yes | Determinism tests exist |
| **Math.KDE** | ✅ Yes | Unit tests exist |
| **Security** | ✅ Yes | Atom exhaustion tested |
| **Integration** | ✅ Yes | End-to-end smoke tests |

---

## Critical Gaps (P0)

### 1. Scout.Easy API - UNTESTED ❌
**Priority**: P0 (BLOCKER)
**Impact**: Main user-facing API has zero test coverage

Missing tests:
- `optimize/3` basic usage
- `optimize/4` with all option combinations
- Error handling (invalid params, empty search space)
- Integration with different samplers
- Integration with different pruners
- Integration with different executors

**Estimated effort**: 4 hours
**Estimated test count**: 30-50 test cases

---

### 2. Sampler Modules - UNTESTED ❌
**Priority**: P0 (HIGH)
**Impact**: Core optimization algorithms have no unit tests

Core samplers needing tests:
1. **Random** (baseline) - 5 test cases
2. **TPE** (main algorithm) - 20 test cases
3. **Grid** - 10 test cases
4. **CMA-ES** - 15 test cases
5. **NSGA-II** - 15 test cases
6. **MOTPE** - 15 test cases

Test requirements per sampler:
- ✅ Initialization (empty history)
- ✅ Sampling with history
- ✅ Determinism (same seed → same result)
- ✅ Convergence (gets better over time)
- ✅ Edge cases (1 trial, 1000 trials, high dimensions)
- ✅ Property-based tests (valid params always generated)

**Estimated effort**: 12 hours (2 hours per sampler)
**Estimated test count**: 80+ test cases

---

### 3. Pruner Modules - UNTESTED ❌
**Priority**: P0 (HIGH)
**Impact**: Early stopping logic has no verification

Pruners needing tests:
1. **Median** - 8 test cases
2. **Percentile** - 8 test cases
3. **Hyperband** - 12 test cases
4. **SuccessiveHalving** - 12 test cases
5. **Patient** - 6 test cases
6. **Threshold** - 6 test cases
7. **Wilcoxon** - 8 test cases

Test requirements per pruner:
- ✅ No pruning (insufficient data)
- ✅ Immediate pruning (clearly bad trial)
- ✅ Intermediate pruning (step-by-step)
- ✅ Edge cases (NaN values, empty history)

**Estimated effort**: 8 hours
**Estimated test count**: 60+ test cases

---

## Infrastructure Blockers (RESOLVED + NEW ISSUES)

### ✅ Postgres Dependency - RESOLVED
Started Postgres 14 via Homebrew:
```bash
brew services start postgresql@14
mix ecto.create  # ✅ Success
mix ecto.migrate # ✅ Success
```

### ❌ NEW BLOCKER: Duplicate Migration Timestamps
```
** (Ecto.MigrationError) migrations can't be executed, migration version 20240824 is duplicated
```

**Root Cause**: During umbrella conversion, migrations were copied/moved creating duplicates

**Impact**: Cannot run tests until migrations are deduplicated

**Fix Required**:
1. List all migration files: `ls -la priv/migrations/`
2. Identify duplicates by timestamp prefix
3. Rename or delete duplicate migrations
4. Ensure migration sequence is correct

### ❌ NEW BLOCKER: Missing child_spec in Scout.Store.Postgres
**Status**: FIXED - Added no-op child_spec that returns `:ignore`

Scout.Store.Postgres doesn't need supervision (Scout.Repo handles DB connection pooling)

---

## Recommended Test Strategy

### Phase 1: Public API (scout-9ei) - 4 hours
Create `test/easy_test.exs` covering:
1. Basic optimization with defaults
2. All sampler options
3. All pruner options
4. All executor options
5. Error handling
6. Edge cases

**Target**: 100% coverage of Scout.Easy module

---

### Phase 2: Samplers (scout-7mh) - 12 hours
Create test files for each sampler:
- `test/sampler/random_test.exs`
- `test/sampler/tpe_test.exs`
- `test/sampler/grid_test.exs`
- `test/sampler/cmaes_test.exs`
- `test/sampler/nsga2_test.exs`
- `test/sampler/motpe_test.exs`

Use property-based testing (StreamData) for:
- Parameter validity
- Determinism
- Convergence properties

**Target**: 90%+ coverage of core samplers

---

### Phase 3: Pruners (scout-7ex) - 8 hours
Create test files for each pruner:
- `test/pruner/median_test.exs`
- `test/pruner/percentile_test.exs`
- `test/pruner/hyperband_test.exs`
- `test/pruner/successive_halving_test.exs`
- `test/pruner/patient_test.exs`
- `test/pruner/threshold_test.exs`
- `test/pruner/wilcoxon_test.exs`

**Target**: 90%+ coverage of all pruners

---

### Phase 4: Store Adapters (scout-8w3) - 3 hours
Enhance existing tests:
- Add edge case coverage
- Add concurrent access tests
- Add transaction rollback tests

**Target**: 95%+ coverage of ETS and Postgres adapters

---

### Phase 5: Utilities (scout-env) - 2 hours
Enhance existing tests:
- More RNG edge cases
- SafeAtoms stress tests
- Seed derivation edge cases

**Target**: 85%+ coverage of utilities

---

## Coverage Goals

Based on .coveralls.exs configuration:

### Minimum Thresholds
- **Public API**: 100% (Scout.Easy)
- **Core Samplers**: 90% (Random, TPE, Grid, CMA-ES, NSGA-II, MOTPE)
- **Pruners**: 90% (All pruners)
- **Store Adapters**: 95% (ETS, Postgres)
- **Utilities**: 85% (RNG, SafeAtoms, etc.)
- **Overall**: 90%+ (excluding experimental modules)

### Excluded from Coverage
Per `.coveralls.exs`:
- `lib/store/ets_hardened.ex` (experimental)
- `lib/sampler/multivariate_tpe_v2.ex` (V2 experimental)

---

## Compiler Warnings Analysis

### Critical Issues
1. **`Scout.Store.update_trial/2` undefined** - Should be `update_trial/3`
   - Affects: `lib/study_coordinator.ex:250`, `lib/study_coordinator.ex:291`
   - Fix: Update function calls to use 3-arity version

2. **Missing behavior implementations** (ETSHardened)
   - `delete_trial/2` required by Scout.Store.Adapter
   - `list_studies/0` required by Scout.Store.Adapter
   - Fix: Implement missing functions or remove `@behaviour` declaration

3. **Undefined module references**
   - `UUID.uuid4/0` in `ets_hardened.ex:277`
   - Fix: Add `:uuid` dependency or use Ecto.UUID

### Non-Critical (Style)
- 50+ unused variable warnings
- 3 unused alias warnings
- 2 unused function warnings

**Recommendation**: Fix critical issues in Phase 1, defer style warnings to polish phase

---

## Session Summary

### Infrastructure Fixes Applied
1. ✅ Started Postgres 14 via Homebrew
2. ✅ Created database (`mix ecto.create`)
3. ✅ Fixed Scout.Store.Postgres - Added no-op child_spec
4. ✅ Fixed migrations path - Symlinked priv/repo/migrations to umbrella-level migrations
5. ✅ Fixed test file syntax error - Changed `≈` to `assert_in_delta`
6. ✅ Fixed AdapterSpec macro - Moved `use ExUnit.Case` to `__using__` block

### Quantitative Coverage Measurement
**STATUS**: Blocked by long test execution time

**Recommendation**: Run `mix test --cover` overnight or in CI to get actual coverage numbers

### Qualitative Analysis Complete
- 74 source files analyzed
- 10 test files inventoried
- Critical gaps identified (Scout.Easy, Samplers, Pruners)
- Test strategy documented

## Next Steps

1. ✅ ~~Start Postgres~~
2. ⏳ **Run full coverage baseline** (`mix coveralls.html`) - In progress
3. ⏸️ **Document actual coverage %** - Pending test completion
4. ⏸️ **Start scout-9ei** (Test coverage: Scout.Easy API) - Ready to start once baseline complete

---

## Appendix: Test File Size Estimates

| Module | Test File | Estimated LOC | Test Cases |
|--------|-----------|---------------|------------|
| Scout.Easy | `test/easy_test.exs` | 300-400 | 30-50 |
| Random | `test/sampler/random_test.exs` | 50-80 | 5-10 |
| TPE | `test/sampler/tpe_test.exs` | 200-300 | 20-30 |
| Grid | `test/sampler/grid_test.exs` | 100-150 | 10-15 |
| CMA-ES | `test/sampler/cmaes_test.exs` | 150-200 | 15-20 |
| NSGA-II | `test/sampler/nsga2_test.exs` | 150-200 | 15-20 |
| MOTPE | `test/sampler/motpe_test.exs` | 150-200 | 15-20 |
| Median Pruner | `test/pruner/median_test.exs` | 80-120 | 8-12 |
| Percentile Pruner | `test/pruner/percentile_test.exs` | 80-120 | 8-12 |
| Hyperband | `test/pruner/hyperband_test.exs` | 120-180 | 12-18 |
| SuccessiveHalving | `test/pruner/successive_halving_test.exs` | 120-180 | 12-18 |

**Total estimated**: ~1500-2300 lines of test code, 150-225 test cases

---

## Conclusion

Scout has a **13.5% test-to-source ratio** (10 test files for 74 source files), indicating significant coverage gaps. The highest priority is **Scout.Easy** (main API), followed by **core samplers** and **pruners**.

**Blocker**: PostgreSQL required for test execution. Use Docker to unblock.

**Beads Task Status**: scout-30a analysis complete, blocked on Postgres for quantitative coverage measurement. Ready to proceed to scout-9ei once infrastructure is available.
