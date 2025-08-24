#!/usr/bin/env python3

"""
OPTUNA SIDE: Real hyperparameter optimization scenarios
This demonstrates all the ways users actually use Optuna in practice
"""

import optuna
import numpy as np
import time
import math
import random

print("🐍 OPTUNA REFERENCE IMPLEMENTATION")
print("=" * 50)
print("Showing real-world Optuna usage patterns that Scout must match")

# Suppress Optuna's verbose logging for cleaner output
optuna.logging.set_verbosity(optuna.logging.WARNING)

# =============================================================================
# TEST 1: Simple Function Optimization (Getting Started)
# =============================================================================
print("\n1️⃣ SIMPLE FUNCTION OPTIMIZATION")
print("-" * 40)

def simple_objective(trial):
    """Classic optimization problem - minimize (x-2)² + (y-3)²"""
    x = trial.suggest_float('x', -5.0, 10.0)
    y = trial.suggest_float('y', -5.0, 10.0)
    
    # Minimize the distance from point (2, 3)
    return (x - 2.0) ** 2 + (y - 3.0) ** 2

# Create study and optimize
study1 = optuna.create_study(direction='minimize')
study1.optimize(simple_objective, n_trials=15)

print(f"Best value: {study1.best_value:.6f} (target: 0.0)")
print(f"Best params: x={study1.best_params['x']:.3f} (target: 2.0), y={study1.best_params['y']:.3f} (target: 3.0)")
distance = math.sqrt((study1.best_params['x'] - 2.0)**2 + (study1.best_params['y'] - 3.0)**2)
print(f"Distance from optimal: {distance:.3f}")

# =============================================================================
# TEST 2: ML Hyperparameter Optimization with Mixed Parameters
# =============================================================================
print("\n2️⃣ ML HYPERPARAMETER OPTIMIZATION")
print("-" * 40)

def ml_objective(trial):
    """Realistic ML model with hyperparameter interactions"""
    # Mixed parameter types like real ML
    learning_rate = trial.suggest_float('learning_rate', 1e-5, 1e-1, log=True)
    architecture = trial.suggest_categorical('architecture', ['simple', 'wide', 'deep'])
    batch_size = trial.suggest_int('batch_size', 16, 256)
    dropout = trial.suggest_float('dropout', 0.0, 0.5)
    n_layers = trial.suggest_int('n_layers', 2, 8)
    optimizer = trial.suggest_categorical('optimizer', ['adam', 'sgd', 'rmsprop'])
    
    # Simulate realistic ML training
    base_accuracy = 0.85
    
    # Learning rate effects (realistic curve)
    if learning_rate > 0.01:
        lr_effect = -0.1  # Too high, exploding gradients
    elif learning_rate < 0.001:
        lr_effect = -0.05  # Too low, slow learning
    else:
        lr_effect = 0.05  # Sweet spot
    
    # Architecture complexity
    arch_effects = {'simple': -0.02, 'wide': 0.02, 'deep': 0.03}
    arch_effect = arch_effects[architecture]
    
    # Layer depth
    if n_layers > 6:
        layer_effect = -0.03  # Too deep, vanishing gradients
    elif n_layers < 3:
        layer_effect = -0.02  # Too shallow
    else:
        layer_effect = 0.02
    
    # Optimizer bonuses
    opt_effects = {'adam': 0.04, 'sgd': 0.02, 'rmsprop': 0.01}
    opt_effect = opt_effects[optimizer]
    
    # Regularization
    if 0.2 <= dropout <= 0.4:
        reg_effect = 0.03  # Good regularization
    else:
        reg_effect = -0.01
    
    # Batch size
    if 32 <= batch_size <= 128:
        batch_effect = 0.02
    else:
        batch_effect = -0.01
        
    # Add realistic noise
    noise = random.gauss(0, 0.02)
    
    # Simulate occasional failures
    if random.random() < 0.05:
        return 0.3  # Failed training
    
    final_accuracy = base_accuracy + lr_effect + arch_effect + layer_effect + opt_effect + reg_effect + batch_effect + noise
    return 1.0 - max(0.0, min(1.0, final_accuracy))  # Return loss (minimize)

# Optimize with more realistic trial count
study2 = optuna.create_study(direction='minimize')
start_time = time.time()
study2.optimize(ml_objective, n_trials=25)
optuna_duration = time.time() - start_time

print(f"Best loss: {study2.best_value:.6f}")
print(f"Best accuracy: {(1.0 - study2.best_value):.4f}")
print(f"Optimization time: {optuna_duration:.2f}s")
print("Best hyperparameters:")
for param, value in study2.best_params.items():
    if isinstance(value, float):
        print(f"  {param}: {value:.6f}")
    else:
        print(f"  {param}: {value}")

# =============================================================================
# TEST 3: Advanced Features - TPE + Pruning
# =============================================================================
print("\n3️⃣ ADVANCED: TPE SAMPLER + HYPERBAND PRUNING")
print("-" * 40)

def advanced_objective(trial):
    """Objective with progressive evaluation for pruning"""
    # Hyperparameters
    lr = trial.suggest_float('learning_rate', 1e-4, 1e-1, log=True)
    n_units = trial.suggest_int('n_units', 32, 512)
    
    # Simulate progressive training with pruning
    best_accuracy = 0.5
    for epoch in range(10):  # Simulate 10 epochs
        # Simulate training progress
        progress = epoch / 9.0
        
        # Learning rate effect
        lr_bonus = 0.3 * math.exp(-abs(math.log10(lr) + 2.5))  # Optimal around 0.003
        
        # Model capacity effect  
        capacity_bonus = 0.2 * min(n_units / 512.0, 1.0)
        
        # Progressive improvement with noise
        epoch_accuracy = 0.6 + progress * (lr_bonus + capacity_bonus) + random.gauss(0, 0.05)
        epoch_accuracy = max(0.0, min(1.0, epoch_accuracy))
        
        best_accuracy = max(best_accuracy, epoch_accuracy)
        
        # Report intermediate result for pruning
        trial.report(epoch_accuracy, epoch)
        
        # Check if trial should be pruned
        if trial.should_prune():
            raise optuna.TrialPruned()
    
    return 1.0 - best_accuracy  # Return loss for minimization

# Create study with TPE and Hyperband
tpe_sampler = optuna.samplers.TPESampler(
    n_startup_trials=5,
    n_ei_candidates=24,
    multivariate=True,
    seed=42
)

hyperband_pruner = optuna.pruners.HyperbandPruner(
    min_resource=1,
    max_resource=10,
    reduction_factor=3
)

study3 = optuna.create_study(
    direction='minimize',
    sampler=tpe_sampler,
    pruner=hyperband_pruner
)

start_time = time.time()
study3.optimize(advanced_objective, n_trials=30)
advanced_duration = time.time() - start_time

print(f"Best loss: {study3.best_value:.6f}")
print(f"Best accuracy: {(1.0 - study3.best_value):.4f}")
print(f"Completed trials: {len([t for t in study3.trials if t.state == optuna.trial.TrialState.COMPLETE])}")
print(f"Pruned trials: {len([t for t in study3.trials if t.state == optuna.trial.TrialState.PRUNED])}")
print(f"Optimization time: {advanced_duration:.2f}s")
print("Best hyperparameters:")
for param, value in study3.best_params.items():
    if isinstance(value, float):
        print(f"  {param}: {value:.6f}")
    else:
        print(f"  {param}: {value}")

# =============================================================================
# TEST 4: Study Management - Persistence and Resumption
# =============================================================================
print("\n4️⃣ STUDY MANAGEMENT: PERSISTENCE")
print("-" * 40)

# Create persistent study
import tempfile
import os

db_file = tempfile.NamedTemporaryFile(delete=False, suffix='.db')
db_file.close()

storage = optuna.storages.RDBStorage(f'sqlite:///{db_file.name}')
study4 = optuna.create_study(
    study_name='persistent_study', 
    storage=storage,
    direction='minimize',
    load_if_exists=True
)

# First round of optimization
study4.optimize(simple_objective, n_trials=10)
trials_after_first = len(study4.trials)
print(f"After first round: {trials_after_first} trials")

# Resume the same study  
study4_resumed = optuna.load_study(
    study_name='persistent_study',
    storage=storage
)

# Second round
study4_resumed.optimize(simple_objective, n_trials=5)
trials_after_resume = len(study4_resumed.trials)
print(f"After resume: {trials_after_resume} trials")
print(f"Study persistence works: {trials_after_resume > trials_after_first}")

# Cleanup
os.unlink(db_file.name)

# =============================================================================
# SUMMARY OF OPTUNA CAPABILITIES TO MATCH
# =============================================================================
print("\n" + "="*60)
print("📋 OPTUNA CAPABILITIES SCOUT MUST MATCH")
print("="*60)
print("✅ Simple 3-line API: create_study() + optimize() + best_params")
print("✅ Mixed parameter types: float, int, categorical, log-scale")
print("✅ Advanced samplers: TPE with multivariate correlation")
print("✅ Pruning algorithms: Hyperband for early stopping")
print("✅ Study persistence: SQLite storage + resumption")
print("✅ Trial states: COMPLETE, PRUNED, FAILED")
print("✅ Progressive evaluation: report() + should_prune()")
print("✅ Realistic ML scenarios: hyperparameter interactions")
print("✅ Error handling: graceful failure recovery")
print("✅ Performance: 25-30 trials in seconds")

print("\n🎯 CHALLENGE FOR SCOUT:")
print("Match this exact functionality with Elixir/BEAM advantages!")
print("🚀 BONUS: Add real-time dashboard + fault tolerance + distribution")