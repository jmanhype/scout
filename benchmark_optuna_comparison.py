#!/usr/bin/env python3
"""
Optuna vs Scout benchmark comparison
Run identical benchmarks on both frameworks for honest comparison
"""
import optuna
import numpy as np
from typing import Callable

# Same test functions as Scout benchmarks
def sphere(x):
    """Simple convex bowl - Sphere function"""
    return sum(xi**2 for xi in x)

def rosenbrock(x):
    """Narrow valley - Rosenbrock function"""
    return sum(100*(x[i+1] - x[i]**2)**2 + (1-x[i])**2 for i in range(len(x)-1))

def rastrigin(x):
    """Highly multimodal - Rastrigin function"""
    A = 10
    n = len(x)
    return A*n + sum(xi**2 - A*np.cos(2*np.pi*xi) for xi in x)

def ackley(x):
    """Multiple local minima - Ackley function"""
    n = len(x)
    sum1 = sum(xi**2 for xi in x)
    sum2 = sum(np.cos(2*np.pi*xi) for xi in x)
    return -20*np.exp(-0.2*np.sqrt(sum1/n)) - np.exp(sum2/n) + 20 + np.e

# Benchmark runner
def run_optuna_benchmark(func: Callable, n_dims: int, bounds: tuple, n_trials: int = 100, n_runs: int = 10):
    """Run Optuna RandomSampler on a test function"""
    results = []

    for run in range(n_runs):
        def objective(trial):
            x = [trial.suggest_float(f'x{i}', bounds[0], bounds[1]) for i in range(n_dims)]
            return func(x)

        study = optuna.create_study(sampler=optuna.samplers.RandomSampler())
        study.optimize(objective, n_trials=n_trials, show_progress_bar=False)
        results.append(study.best_value)

    return np.mean(results), np.std(results)

# Run benchmarks
print("Running Optuna RandomSampler benchmarks...")
print("=" * 60)

benchmarks = [
    ("Sphere (5D)", sphere, 5, (-5.0, 5.0)),
    ("Rosenbrock (2D)", rosenbrock, 2, (-2.0, 2.0)),
    ("Rastrigin (5D)", rastrigin, 5, (-5.12, 5.12)),
    ("Ackley (2D)", ackley, 2, (-5.0, 5.0)),
]

for name, func, dims, bounds in benchmarks:
    mean, std = run_optuna_benchmark(func, dims, bounds)
    print(f"{name:20s} | {mean:8.2f} ± {std:5.2f}")

print("=" * 60)
print("\nNow compare these with Scout's numbers:")
print("Sphere (5D):      8.21 ± 2.28")
print("Rosenbrock (2D):  0.29 ± 0.34")
print("Rastrigin (5D):  32.55 ± 9.07")
print("Ackley (2D):      2.36 ± 1.21")
