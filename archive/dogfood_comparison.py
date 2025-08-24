#!/usr/bin/env python3
"""
Optuna side of dogfooding comparison.
Run identical optimization problems that we'll replicate in Scout.
"""

import optuna
import numpy as np
import json
from typing import Dict, List, Any
import math

def objective_2d_quadratic(trial):
    """Simple 2D quadratic: minimize (x-2)² + (y+1)²"""
    x = trial.suggest_float('x', -5, 5)
    y = trial.suggest_float('y', -5, 5)
    return (x - 2)**2 + (y + 1)**2

def objective_ml_hyperparams(trial):
    """ML hyperparameter optimization"""
    lr = trial.suggest_float('learning_rate', 1e-5, 1e-1, log=True)
    batch_size = trial.suggest_categorical('batch_size', [16, 32, 64, 128])
    layers = trial.suggest_int('hidden_layers', 1, 5)
    dropout = trial.suggest_float('dropout', 0.0, 0.5, step=0.1)
    
    # Simulate ML training objective
    # Penalty for extreme values
    lr_penalty = abs(math.log10(lr) + 3) * 0.1  # Optimal around 1e-3
    batch_penalty = abs(batch_size - 64) * 0.001  # Prefer batch_size 64
    layer_penalty = abs(layers - 3) * 0.05  # Prefer 3 layers
    dropout_penalty = abs(dropout - 0.3) * 0.2  # Prefer 0.3 dropout
    
    # Add some noise
    noise = np.random.normal(0, 0.02)
    
    return lr_penalty + batch_penalty + layer_penalty + dropout_penalty + noise + 0.5

def objective_rosenbrock(trial):
    """Rosenbrock function: f(x,y) = (a-x)² + b(y-x²)²"""
    x = trial.suggest_float('x', -2, 2)
    y = trial.suggest_float('y', -2, 2)
    a, b = 1, 100
    return (a - x)**2 + b * (y - x**2)**2

def run_optuna_study(objective_func, sampler_name, n_trials=50, study_name="test"):
    """Run an Optuna study and return results"""
    
    # Create sampler
    if sampler_name == "random":
        sampler = optuna.samplers.RandomSampler(seed=42)
    elif sampler_name == "tpe":
        sampler = optuna.samplers.TPESampler(seed=42, n_startup_trials=10)
    elif sampler_name == "grid":
        # For grid search, we need to define the search space
        if objective_func.__name__ == "objective_2d_quadratic":
            search_space = {
                'x': [-5, -2.5, 0, 2.5, 5],
                'y': [-5, -2.5, 0, 2.5, 5]
            }
        else:
            # Use fewer grid points for complex spaces
            search_space = {}
        sampler = optuna.samplers.GridSampler(search_space) if search_space else optuna.samplers.RandomSampler(seed=42)
    else:
        sampler = optuna.samplers.RandomSampler(seed=42)
    
    # Create and run study
    study = optuna.create_study(
        direction='minimize',
        sampler=sampler,
        study_name=study_name
    )
    
    study.optimize(objective_func, n_trials=n_trials)
    
    # Collect results
    results = {
        'study_name': study_name,
        'sampler': sampler_name,
        'n_trials': n_trials,
        'best_value': study.best_value,
        'best_params': study.best_params,
        'trials': []
    }
    
    for trial in study.trials:
        if trial.state == optuna.trial.TrialState.COMPLETE:
            results['trials'].append({
                'number': trial.number,
                'value': trial.value,
                'params': trial.params
            })
    
    return results

def main():
    print("🐍 Running Optuna Dogfooding Tests")
    print("=" * 60)
    
    all_results = {}
    
    # Test 1: Simple 2D Quadratic
    print("\n📊 Test 1: 2D Quadratic Optimization")
    print("Objective: minimize (x-2)² + (y+1)²")
    print("Optimal: x=2, y=-1, value=0")
    
    for sampler in ["random", "tpe", "grid"]:
        print(f"\n  Running {sampler} sampler...")
        results = run_optuna_study(
            objective_2d_quadratic, 
            sampler, 
            n_trials=25,
            study_name=f"2d_quadratic_{sampler}"
        )
        
        print(f"    Best result: {results['best_params']} → {results['best_value']:.6f}")
        all_results[f"2d_quadratic_{sampler}"] = results
    
    # Test 2: ML Hyperparameters
    print("\n🤖 Test 2: ML Hyperparameter Optimization")
    print("Objective: Simulated ML training loss")
    
    for sampler in ["random", "tpe"]:  # Skip grid for complex space
        print(f"\n  Running {sampler} sampler...")
        results = run_optuna_study(
            objective_ml_hyperparams,
            sampler,
            n_trials=30,
            study_name=f"ml_hyperparams_{sampler}"
        )
        
        best = results['best_params']
        print(f"    Best config: lr={best['learning_rate']:.2e}, batch={best['batch_size']}, layers={best['hidden_layers']}, dropout={best['dropout']}")
        print(f"    Best value: {results['best_value']:.6f}")
        all_results[f"ml_hyperparams_{sampler}"] = results
    
    # Test 3: Rosenbrock Function
    print("\n🌹 Test 3: Rosenbrock Function")
    print("Objective: (1-x)² + 100(y-x²)²")
    print("Optimal: x=1, y=1, value=0")
    
    for sampler in ["random", "tpe"]:
        print(f"\n  Running {sampler} sampler...")
        results = run_optuna_study(
            objective_rosenbrock,
            sampler,
            n_trials=100,
            study_name=f"rosenbrock_{sampler}"
        )
        
        print(f"    Best result: {results['best_params']} → {results['best_value']:.6f}")
        all_results[f"rosenbrock_{sampler}"] = results
    
    # Save results
    with open('optuna_dogfood_results.json', 'w') as f:
        json.dump(all_results, f, indent=2)
    
    print(f"\n✅ Optuna results saved to optuna_dogfood_results.json")
    print(f"📊 Total studies: {len(all_results)}")
    
    # Summary statistics
    print("\n📈 Summary:")
    for study_name, results in all_results.items():
        convergence_rate = len(results['trials']) / results['n_trials']
        print(f"  {study_name}: {results['best_value']:.6f} ({convergence_rate*100:.0f}% trials completed)")

if __name__ == "__main__":
    main()