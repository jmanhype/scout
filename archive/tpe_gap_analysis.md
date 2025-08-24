# TPE Implementation Gap Analysis: Scout vs Optuna

## Executive Summary
After dogfooding validation, Scout shows 30-171% performance gaps compared to Optuna despite having all major TPE features implemented. This analysis identifies the root causes.

## Key Differences Found

### 1. Default Parameters (CRITICAL)
**Optuna TPE Defaults:**
- `gamma`: 0.5 (splits at median - 50% good/bad)
- `n_startup_trials`: 10
- `n_ei_candidates`: 24

**Scout TPE Defaults:**
- `gamma`: 0.15 (splits at 15% - much smaller "good" group)
- `min_obs`: 20 (waits longer before using TPE)
- `n_candidates`: 24

**Impact:** Scout's gamma=0.15 means only the top 15% of trials are considered "good", making the good distribution much more selective but potentially less informative early on.

### 2. KDE Bandwidth Calculation
**Optuna:** Uses Scott's rule with modifications
- Bandwidth = 0.9 * std * n^(-0.2)
- Has sophisticated multivariate KDE for correlated parameters

**Scout:** Simplified univariate approach
- Bandwidth = max(0.9 * std * n^(-0.2), (max-min) * 0.001)
- No multivariate support yet

### 3. Integer Parameter Handling
**Scout Issue:** 
```elixir
# Line 28 in SearchSpace.ex
defp sample_param({:int, min, max}) do
  min + :rand.uniform(max - min + 1) - 1
end
```
This can produce values outside the range when used with TPE's continuous sampling.

### 4. Log-space Transformation
**Scout:** Correctly transforms to log space for sampling but the KDE is built on raw values, not log-transformed values.

### 5. Performance Results
```
ML Hyperparameters:
- Optuna: 0.733
- Scout:  0.510 (30% gap)

Rastrigin Benchmark:
- Optuna: 2.280
- Scout:  6.180 (171% gap)
```

## Root Causes Identified

1. **Gamma Parameter Mismatch:** Scout's aggressive 0.15 vs Optuna's balanced 0.5
2. **Startup Trials:** Scout waits for 20 trials vs Optuna's 10
3. **Integer Sampling:** Potential boundary issues in Scout
4. **Log-space KDE:** Scout builds KDE on raw values instead of log-transformed

## Recommended Fixes

### Fix 1: Align Default Parameters
```elixir
def init(opts) do
  %{
    gamma: Map.get(opts, :gamma, 0.5),  # Changed from 0.15
    n_candidates: Map.get(opts, :n_candidates, 24),
    min_obs: Map.get(opts, :min_obs, 10),  # Changed from 20
    bw_floor: Map.get(opts, :bw_floor, 1.0e-3),
    goal: Map.get(opts, :goal, :maximize),
    seed: Map.get(opts, :seed)
  }
end
```

### Fix 2: Improve Integer Handling
```elixir
# In TPE sampling for integers
{:int, min, max} ->
  # Sample continuous value and round
  %{good: g} = Map.get(dists, k, %{good: %{xs: [], sigmas: []}, range: {min, max}})
  {mu, si} = pick_component(g)
  x = clamp(:rand.normal(mu, si), min, max)
  Map.put(acc, k, round(x))  # Round to nearest integer
```

### Fix 3: Build KDE in Transformed Space
```elixir
# For log_uniform parameters
defp build_kdes(k, obs, state, {:log_uniform, min, max}) do
  # Transform observations to log space
  log_obs = Enum.map(obs, fn {p, s} -> 
    {Map.update(p, k, 0, &:math.log/1), s}
  end)
  # Build KDE in log space
  sorted = sort_by_goal(log_obs, state.goal)
  # ... rest of KDE building
end
```

## Validation Plan

1. Create `tpe_fixes.ex` with corrected parameters
2. Run side-by-side comparison with Optuna
3. Measure performance improvements
4. Document remaining gaps

## Conclusion

The dogfooding approach successfully revealed critical implementation differences that unit tests missed. The main issue is parameter tuning (gamma, min_obs) rather than algorithmic correctness. With these fixes, Scout should achieve >90% parity with Optuna's TPE performance.