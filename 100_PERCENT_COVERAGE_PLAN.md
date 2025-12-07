# Scout v0.3.0 - 100% Test Coverage Plan

**Goal**: Achieve 100% test coverage + comprehensive benchmarks before Hex publishing
**Timeline**: 4-6 hours of focused work
**Current Status**: TBD (running initial coverage scan)

---

## Phase 1: Coverage Baseline (30 min)

### Tasks
- [x] Add ExCoveralls to deps
- [x] Configure `.coveralls.exs` with 100% threshold
- [ ] Run `mix coveralls.html` to generate current report
- [ ] Identify uncovered modules
- [ ] Categorize by priority (public API vs internal)

### Expected Outcome
Coverage report showing gaps in:
1. Sampler algorithms (TPE, CMA-ES, NSGA-II, etc.)
2. Pruner implementations
3. Store adapters (ETS, Postgres)
4. Executor implementations (Local, Oban)
5. Util modules (RNG, Safe atoms, etc.)

---

## Phase 2: Public API Coverage (2 hours)

**Priority**: Cover all user-facing modules first

### Critical Modules (Must be 100%)
1. **Scout.Easy** - Main user API
   - `optimize/3`
   - `optimize/4` with all options
   - Error handling paths

2. **Scout.Sampler.***
   - TPE (all variants)
   - Random
   - Grid
   - CMA-ES
   - NSGA-II
   - Test edge cases (empty history, invalid params)

3. **Scout.Pruner.***
   - Median
   - Percentile
   - Hyperband
   - SuccessiveHalving
   - Edge cases (no pruning, early pruning)

4. **Scout.Store**
   - ETS adapter (all CRUD operations)
   - Postgres adapter (all CRUD operations)
   - Transaction rollback paths
   - Concurrent access scenarios

### Test Strategy
- **Property-based testing** for samplers (use StreamData)
- **Convergence tests** for algorithms
- **Concurrency tests** for store
- **Error injection** for edge cases

---

## Phase 3: Internal Module Coverage (1 hour)

### Support Modules
1. **Scout.Util.RNG** - Deterministic seeding
2. **Scout.Util.SafeAtoms** - Atom exhaustion protection
3. **Scout.Math.KDE** - Kernel density estimation
4. **Scout.SearchSpace** - Parameter space handling
5. **Scout.Constraints** - Constraint validation

### Test Strategy
- **Unit tests** for each function
- **Boundary conditions** (empty lists, zero values, etc.)
- **Mathematical correctness** (compare to known values)

---

## Phase 4: Integration Coverage (1 hour)

### End-to-End Scenarios
1. **Full optimization workflow**
   - Create study → Run trials → Get results
   - With different samplers
   - With different pruners
   - With different executors

2. **Persistence scenarios**
   - Save/resume studies
   - Crash recovery
   - Concurrent studies

3. **Distributed scenarios**
   - Oban job execution
   - Multi-node optimization (if possible in test)

### Test Strategy
- **Smoke tests** for happy paths
- **Chaos tests** for failure scenarios
- **Property-based** for invariants (study integrity)

---

## Phase 5: Benchmark Suite (2 hours)

### Required Benchmarks

#### 1. **Optuna Parity Benchmark** (`benchmark/optuna_parity.exs`)
Test functions:
- Rosenbrock (2D, 10D)
- Rastrigin (2D, 10D)
- Ackley (2D)
- Schwefel (2D)
- Sphere (10D, 100D)

Metrics:
- Best value (mean ± std over 10 runs)
- Convergence speed (trials to 95% optimum)
- Statistical significance (Mann-Whitney U, p-value)

Expected results table:
```
| Function    | Dims | Optuna      | Scout       | p-value | Status |
|-------------|------|-------------|-------------|---------|--------|
| Rosenbrock  | 2D   | 0.231±0.05  | 0.231±0.04  | 0.89    | ✅ Par |
| Rosenbrock  | 10D  | 12.3±2.1    | 12.1±1.9    | 0.71    | ✅ Par |
| ...         |      |             |             |         |        |
```

#### 2. **Sampler Comparison Benchmark** (`benchmark/sampler_comparison.exs`)
Compare all samplers on same test suite:
- Random (baseline)
- TPE
- CMA-ES
- Grid
- NSGA-II (multi-objective)

Show convergence plots (ASCII art in terminal)

#### 3. **Pruner Effectiveness Benchmark** (`benchmark/pruner_effectiveness.exs`)
Measure pruning efficiency:
- Trials saved (% of trials pruned early)
- Time saved
- Quality maintained (final best value vs no-pruning)

#### 4. **Scaling Benchmark** (`benchmark/scaling.exs`)
Test performance with:
- 1, 10, 100, 1000 trials
- 2, 10, 50, 100 dimensional search spaces
- Sequential vs parallel execution

Expected output:
```
Scaling Results:
- 1000 trials, 2D:   15.3s (65.3 trials/sec)
- 1000 trials, 10D:  18.7s (53.4 trials/sec)
- 1000 trials, 50D:  32.1s (31.1 trials/sec)
```

### Benchmark Documentation (`BENCHMARK_RESULTS.md`)
- Methodology section
- Hardware/software specs
- Reproduction instructions
- Results tables
- Statistical analysis

---

## Phase 6: Documentation & Polish (30 min)

### Tasks
- [ ] Add "Test Coverage" badge to README (100%)
- [ ] Link to BENCHMARK_RESULTS.md from README
- [ ] Update CHANGELOG with coverage milestone
- [ ] Add coverage to CI/CD (GitHub Actions)
- [ ] Document how to run benchmarks

### CI Configuration (`.github/workflows/ci.yml`)
```yaml
- name: Run Tests with Coverage
  run: mix coveralls.github
  env:
    MIX_ENV: test
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

- name: Enforce 100% Coverage
  run: |
    COVERAGE=$(mix coveralls.json | grep "\"total\":" | awk '{print $2}' | tr -d ',')
    if (( $(echo "$COVERAGE < 100.0" | bc -l) )); then
      echo "Coverage $COVERAGE% is below 100%"
      exit 1
    fi
```

---

## Success Criteria

Before publishing to Hex, verify:
- [ ] `mix coveralls` shows 100.0% coverage
- [ ] All benchmarks run successfully
- [ ] BENCHMARK_RESULTS.md documents parity with Optuna
- [ ] README links to coverage and benchmarks
- [ ] CI enforces coverage threshold
- [ ] All tests pass (mix test)
- [ ] No compiler warnings
- [ ] Package builds (mix hex.build)

---

## Risk Mitigation

### If 100% proves impossible:
1. **Exclude experimental modules** (add to `.coveralls.exs` skip_files)
2. **Set pragmatic threshold** (95% core API, 80% overall)
3. **Document uncovered code** with explanation

### If benchmarks show Scout underperforms:
1. **Identify algorithmic issues** (RNG, TPE implementation)
2. **Fix or document limitations**
3. **Be honest in README** (don't claim parity if not true)

---

## Estimated Effort

| Phase | Time | Cumulative |
|-------|------|------------|
| Baseline | 30m | 30m |
| Public API | 2h | 2.5h |
| Internal | 1h | 3.5h |
| Integration | 1h | 4.5h |
| Benchmarks | 2h | 6.5h |
| Docs | 30m | 7h |

**Total**: ~7 hours for complete coverage + benchmarks

---

**Next Step**: Run `mix coveralls.html` to see current coverage baseline
