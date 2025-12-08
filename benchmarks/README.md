# Scout Benchmarks & Performance Analysis

This directory contains performance profiling, benchmarking, and optimization analysis for Scout.

## Files

### Benchmarking Scripts

- **`benchmark_optuna_comparison.py`** - Side-by-side comparison with Optuna (Python)
  - Runs identical benchmarks on both frameworks
  - Generates honest performance data
  - Run: `python3 benchmark_optuna_comparison.py`

- **`benchmark_incremental_sort.exs`** - Validates TPE sorting optimization
  - Tests incremental sorting vs full re-sort
  - Shows 4-5x speedup in realistic workflows
  - Run: `elixir benchmark_incremental_sort.exs`

- **`benchmark_optimization.exs`** - Tests caching optimization (failed approach)
  - Shows why naive caching doesn't work
  - Documented for learning purposes
  - Run: `elixir benchmark_optimization.exs`

### Profiling Scripts

- **`profile_scout_real.exs`** - Comprehensive performance profiling
  - Measures all Scout operations (study creation, trials, sampling, storage)
  - Identifies bottlenecks (found TPE sorting at 85 μs)
  - Run: `elixir profile_scout_real.exs`

- **`profile_scout.exs`** - Benchee-based profiling (requires deps)
  - More detailed statistical analysis
  - Run: `cd apps/scout_core && elixir ../../profile_scout.exs`

### Analysis Documents

- **`PERFORMANCE_ANALYSIS.md`** - Post-mortem on optimization attempts
  - Why caching failed (cache invalidation)
  - Why incremental sorting succeeded
  - Real-world vs predicted performance

- **`PERFORMANCE_OPTIMIZATIONS.md`** - Optimization strategy document
  - Profiling results and bottleneck identification
  - Proposed optimizations with impact estimates
  - Implementation roadmap

## Quick Start

```bash
# Run Optuna comparison (requires Python + Optuna)
python3 benchmark_optuna_comparison.py

# Run TPE optimization benchmark
elixir benchmark_incremental_sort.exs

# Profile Scout operations
elixir profile_scout_real.exs
```

## Results Summary

| Optimization | Expected | Actual | Status |
|--------------|----------|--------|--------|
| TPE Caching | 10-20x | 0.72-1.25x | ❌ Failed |
| Incremental Sort | 4-6x | 4-5x | ✅ **Success** |
| Optuna Parity | Claims | Measured & validated | ✅ **Verified** |

## Key Findings

1. **TPE Sorting** is the main bottleneck (85 μs per sort with 1000 trials)
2. **Incremental sorting** provides 4-5x speedup in realistic workflows
3. **Scout performs equivalently** to Optuna on standard benchmarks
4. **Cache invalidation** kills naive caching strategies

See individual files for detailed analysis and reproduction steps.
