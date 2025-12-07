# Scout vs Optuna: Comprehensive Dogfooding Plan

## Current Status Summary

### What Scout Has ✅
1. **Core Optimization**
   - Tree-structured Parzen Estimator (TPE) with multivariate support
   - Random search
   - Grid search
   - Bandit-based sampling

2. **Execution**
   - Local execution
   - Distributed via Oban (Elixir's job queue)
   - Fault-tolerant trial execution

3. **Pruning**
   - Successive Halving
   - Median pruner

4. **Persistence**
   - ETS (in-memory)
   - Ecto/PostgreSQL (durable)

5. **Monitoring**
   - Phoenix LiveView dashboard
   - Real-time trial updates
   - Telemetry events

### What Optuna Has That Scout Lacks ❌

## Feature Comparison Matrix

| Category | Feature | Optuna | Scout | Priority | Effort |
|----------|---------|--------|-------|----------|--------|
| **Samplers** |
| | TPE (univariate) | ✅ | ✅ | - | - |
| | TPE (multivariate) | ✅ | ✅ | - | - |
| | CMA-ES | ✅ | 🔧 Partial | High | Medium |
| | GP-EI (Gaussian Process) | ✅ | ❌ | Medium | High |
| | Random Search | ✅ | ✅ | - | - |
| | Grid Search | ✅ | ✅ | - | - |
| | QMC Sampler | ✅ | ❌ | Low | Medium |
| | NSGA-II (multi-objective) | ✅ | ❌ | Medium | High |
| | MOTPE (multi-objective TPE) | ✅ | ❌ | Medium | High |
| **Pruners** |
| | MedianPruner | ✅ | ✅ | - | - |
| | SuccessiveHalving | ✅ | ✅ | - | - |
| | Hyperband | ✅ | ❌ | High | Medium |
| | ThresholdPruner | ✅ | ❌ | Low | Low |
| | PercentilePruner | ✅ | ❌ | Low | Low |
| | PatientPruner | ✅ | ❌ | Medium | Low |
| **Search Space** |
| | Continuous parameters | ✅ | ✅ | - | - |
| | Integer parameters | ✅ | ✅ | - | - |
| | Categorical parameters | ✅ | ✅ | - | - |
| | Conditional parameters | ✅ | ❌ | High | High |
| | Discrete uniform | ✅ | ❌ | Low | Low |
| | Log-uniform distribution | ✅ | ✅ | - | - |
| | Parameter constraints | ✅ | ❌ | Medium | Medium |
| **Study Management** |
| | Create/delete studies | ✅ | ✅ | - | - |
| | Study naming | ✅ | ✅ | - | - |
| | Study directions (min/max) | ✅ | ✅ | - | - |
| | Multi-objective | ✅ | ❌ | Medium | High |
| | Study summaries | ✅ | 🔧 Basic | Medium | Low |
| | Best trial tracking | ✅ | ✅ | - | - |
| | Trial user attributes | ✅ | ❌ | Low | Low |
| | Study user attributes | ✅ | ❌ | Low | Low |
| **Visualization** |
| | Optimization history | ✅ | 🔧 Basic | High | Medium |
| | Parallel coordinate | ✅ | ❌ | High | Medium |
| | Contour plots | ✅ | ❌ | Medium | Medium |
| | Slice plots | ✅ | ❌ | Medium | Medium |
| | Importance plots | ✅ | ❌ | High | High |
| | EDF plots | ✅ | ❌ | Low | Low |
| | Pareto front (multi-obj) | ✅ | ❌ | Low | Medium |
| **Integration** |
| | CLI interface | ✅ | ✅ | - | - |
| | Dashboard UI | ✅ | ✅ | - | - |
| | Distributed execution | ✅ | ✅ | - | - |
| | Callbacks/hooks | ✅ | ❌ | Medium | Medium |
| | Heartbeat for trials | ✅ | ❌ | Low | Medium |
| | Trial garbage collection | ✅ | ❌ | Low | Medium |
| **Advanced Features** |
| | Warm starting | ✅ | 🔧 Basic | Medium | Medium |
| | Transfer learning | ✅ | ❌ | Low | High |
| | Importance evaluation | ✅ | ❌ | Medium | High |
| | Retry failed trials | ✅ | 🔧 Via Oban | - | - |
| | Copy studies | ✅ | ❌ | Low | Low |
| | Enqueue trials | ✅ | ✅ Via Oban | - | - |

## Testing Scenarios

### 1. Basic Optimization (✅ Ready to Test)
```elixir
# Scout version
study = %{
  objective: fn params -> 
    x = params[:x]
    (x - 2) ** 2
  end,
  search_space: fn _ -> %{
    x: {:uniform, -10, 10}
  } end,
  sampler: Scout.Sampler.TPE,
  n_trials: 100
}
```

### 2. Distributed Execution (✅ Ready to Test)
```elixir
# Test with Oban executor
study = Map.put(study, :executor, Scout.Executor.Oban)
```

### 3. Advanced Pruning (🔧 Partial)
```elixir
# Need to implement Hyperband
study = Map.put(study, :pruner, Scout.Pruner.Hyperband) # Not yet available
```

### 4. Conditional Parameters (❌ Not Implemented)
```python
# Optuna example we need to match
def objective(trial):
    classifier = trial.suggest_categorical('classifier', ['SVM', 'RandomForest'])
    if classifier == 'SVM':
        c = trial.suggest_float('svm_c', 1e-10, 1e10, log=True)
        kernel = trial.suggest_categorical('svm_kernel', ['linear', 'rbf'])
        if kernel == 'rbf':
            gamma = trial.suggest_float('svm_gamma', 1e-10, 1e10, log=True)
```

### 5. Multi-Objective (❌ Not Implemented)
```python
# Optuna multi-objective
def objective(trial):
    x = trial.suggest_float('x', 0, 5)
    y = trial.suggest_float('y', 0, 5)
    return x**2, (y-2)**2
```

### 6. Visualization (🔧 Basic Dashboard Only)
```python
# Optuna rich visualizations
optuna.visualization.plot_optimization_history(study)
optuna.visualization.plot_parallel_coordinate(study)
optuna.visualization.plot_importance(study)
```

## Immediate Priorities for Parity

### High Priority (Week 1-2)
1. **Hyperband Pruner** - Critical for efficient hyperparameter search
2. **Conditional Parameters** - Common use case for ML model selection
3. **Parameter Importance** - Key insight for users
4. **Better Visualization** - Optimization history plots

### Medium Priority (Week 3-4)
1. **CMA-ES Completion** - Important for continuous optimization
2. **Multi-objective Support** - Growing use case
3. **Study Callbacks** - For custom logging/monitoring
4. **Parameter Constraints** - For complex search spaces

### Low Priority (Future)
1. **QMC Sampler** - Niche use case
2. **Transfer Learning** - Advanced feature
3. **Additional Pruners** - Nice to have
4. **User Attributes** - Metadata management

## Benchmarking Plan

### Performance Tests
1. **Speed**: 1000 trials on Rosenbrock function
2. **Memory**: Memory usage with 10,000 trials
3. **Distributed**: Scaling with 1, 4, 8, 16 workers
4. **Convergence**: Iterations to reach optimum

### Quality Tests
1. **Optimization Quality**: Final objective value
2. **Sample Efficiency**: Trials to reach threshold
3. **Robustness**: Performance with noisy objectives
4. **Diversity**: Parameter space exploration

## Next Steps

1. Start with basic optimization comparison
2. Test distributed execution scaling
3. Implement Hyperband pruner
4. Add conditional parameter support
5. Enhance visualization capabilities
6. Run comprehensive benchmarks
7. Document API differences
8. Create migration guide from Optuna

## Success Metrics

- [ ] Feature parity on core optimization (samplers, pruners)
- [ ] Performance within 20% of Optuna
- [ ] All common use cases supported
- [ ] Clear migration path documented
- [ ] Production-ready with real workloads