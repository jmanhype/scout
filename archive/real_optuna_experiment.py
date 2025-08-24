#!/usr/bin/env python3
"""
REAL Optuna experiment - like a data scientist would actually use it.
Training a real ML model with hyperparameter optimization.
"""

import optuna
import pandas as pd
import numpy as np
from sklearn.datasets import make_classification
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import cross_val_score, train_test_split
from sklearn.metrics import accuracy_score
import sqlite3
import os
import time

def create_dataset():
    """Create a realistic but challenging classification dataset"""
    X, y = make_classification(
        n_samples=2000,
        n_features=20, 
        n_informative=15,
        n_redundant=5,
        n_clusters_per_class=1,
        random_state=42
    )
    
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42
    )
    
    print(f"Dataset: {X_train.shape[0]} train, {X_test.shape[0]} test samples")
    print(f"Features: {X_train.shape[1]}")
    print(f"Classes: {len(np.unique(y))}")
    
    return X_train, X_test, y_train, y_test

def objective(trial):
    """Real ML objective function - optimize RandomForest hyperparameters"""
    
    # Suggest hyperparameters 
    n_estimators = trial.suggest_int('n_estimators', 10, 200)
    max_depth = trial.suggest_int('max_depth', 1, 20)
    min_samples_split = trial.suggest_int('min_samples_split', 2, 20)
    min_samples_leaf = trial.suggest_int('min_samples_leaf', 1, 10)
    max_features = trial.suggest_categorical('max_features', ['sqrt', 'log2', None])
    
    # Create and train model
    clf = RandomForestClassifier(
        n_estimators=n_estimators,
        max_depth=max_depth,
        min_samples_split=min_samples_split,
        min_samples_leaf=min_samples_leaf,
        max_features=max_features,
        random_state=42,
        n_jobs=-1  # Use all cores
    )
    
    # Use cross-validation for robust evaluation
    scores = cross_val_score(clf, X_train, y_train, cv=3, scoring='accuracy')
    
    # Return negative because Optuna minimizes
    return -scores.mean()

def run_optuna_study():
    """Run real Optuna study with persistence, pruning, callbacks"""
    
    print("🐍 Running REAL Optuna Experiment")
    print("=" * 50)
    
    # Create persistent study
    storage_url = "sqlite:///optuna_real_study.db"
    study_name = "random_forest_optimization"
    
    # Try to load existing study or create new one
    try:
        study = optuna.load_study(study_name=study_name, storage=storage_url)
        print(f"📂 Loaded existing study with {len(study.trials)} trials")
    except KeyError:
        study = optuna.create_study(
            study_name=study_name,
            storage=storage_url,
            direction='minimize',
            sampler=optuna.samplers.TPESampler(seed=42),
            pruner=optuna.pruners.MedianPruner(n_startup_trials=5, n_warmup_steps=3)
        )
        print("🆕 Created new study")
    
    # Add study callbacks for monitoring
    def print_callback(study, trial):
        if trial.state == optuna.trial.TrialState.COMPLETE:
            print(f"Trial {trial.number}: {-trial.value:.4f} accuracy")
        elif trial.state == optuna.trial.TrialState.PRUNED:
            print(f"Trial {trial.number}: PRUNED")
    
    # Run optimization
    print(f"🚀 Starting optimization...")
    start_time = time.time()
    
    try:
        study.optimize(
            objective, 
            n_trials=50,
            callbacks=[print_callback],
            timeout=300  # 5 minute timeout
        )
    except KeyboardInterrupt:
        print("\n⏸️  Interrupted by user")
    
    duration = time.time() - start_time
    
    # Results analysis
    print(f"\n📊 OPTUNA RESULTS (completed in {duration:.1f}s)")
    print("=" * 50)
    
    print(f"Total trials: {len(study.trials)}")
    print(f"Best trial: {study.best_trial.number}")
    print(f"Best accuracy: {-study.best_value:.4f}")
    print(f"Best params:")
    
    for key, value in study.best_params.items():
        print(f"  {key}: {value}")
    
    # Test final model
    best_params = study.best_params
    final_model = RandomForestClassifier(**best_params, random_state=42, n_jobs=-1)
    final_model.fit(X_train, y_train)
    
    test_accuracy = accuracy_score(y_test, final_model.predict(X_test))
    print(f"\n🎯 Final test accuracy: {test_accuracy:.4f}")
    
    # Study statistics
    completed_trials = [t for t in study.trials if t.state == optuna.trial.TrialState.COMPLETE]
    pruned_trials = [t for t in study.trials if t.state == optuna.trial.TrialState.PRUNED]
    
    print(f"\n📈 Study Statistics:")
    print(f"  Completed: {len(completed_trials)}")
    print(f"  Pruned: {len(pruned_trials)}")
    print(f"  Pruning rate: {len(pruned_trials)/len(study.trials)*100:.1f}%")
    
    # Save results for comparison
    results = {
        'framework': 'optuna',
        'best_accuracy': -study.best_value,
        'test_accuracy': test_accuracy,
        'total_trials': len(study.trials),
        'completed_trials': len(completed_trials),
        'pruned_trials': len(pruned_trials),
        'duration': duration,
        'best_params': study.best_params
    }
    
    return results

def explore_optuna_features():
    """Try out different Optuna features like a real user"""
    
    print("\n🔬 Exploring Optuna Features")
    print("=" * 50)
    
    # Feature 1: Different samplers
    samplers = {
        'Random': optuna.samplers.RandomSampler(seed=42),
        'TPE': optuna.samplers.TPESampler(seed=42),
        'CMA-ES': optuna.samplers.CmaEsSampler(seed=42)
    }
    
    for sampler_name, sampler in samplers.items():
        print(f"\n🎲 Testing {sampler_name} sampler")
        
        study = optuna.create_study(
            direction='minimize',
            sampler=sampler
        )
        
        study.optimize(objective, n_trials=10)
        print(f"  Best {sampler_name}: {-study.best_value:.4f}")
    
    # Feature 2: Pruning
    print(f"\n✂️  Testing Pruning")
    pruners = {
        'Median': optuna.pruners.MedianPruner(),
        'Successive Halving': optuna.pruners.SuccessiveHalvingPruner(),
        'Hyperband': optuna.pruners.HyperbandPruner()
    }
    
    for pruner_name, pruner in pruners.items():
        study = optuna.create_study(
            direction='minimize',
            sampler=optuna.samplers.TPESampler(seed=42),
            pruner=pruner
        )
        
        study.optimize(objective, n_trials=15)
        pruned = len([t for t in study.trials if t.state == optuna.trial.TrialState.PRUNED])
        print(f"  {pruner_name}: {pruned}/15 trials pruned")
    
    # Feature 3: Multi-objective (if we have time)
    print(f"\n🎯 Multi-objective optimization")
    
    def multi_objective(trial):
        params = {
            'n_estimators': trial.suggest_int('n_estimators', 10, 100),
            'max_depth': trial.suggest_int('max_depth', 1, 10)
        }
        
        clf = RandomForestClassifier(**params, random_state=42, n_jobs=-1)
        scores = cross_val_score(clf, X_train, y_train, cv=3, scoring='accuracy')
        
        accuracy = scores.mean()
        model_size = params['n_estimators'] * params['max_depth']  # Proxy for complexity
        
        return -accuracy, model_size  # Minimize both
    
    study = optuna.create_study(directions=['minimize', 'minimize'])
    study.optimize(multi_objective, n_trials=20)
    
    print(f"  Pareto solutions found: {len(study.best_trials)}")

if __name__ == "__main__":
    # Create dataset
    X_train, X_test, y_train, y_test = create_dataset()
    
    # Run main experiment
    results = run_optuna_study()
    
    # Explore features
    explore_optuna_features()
    
    print(f"\n✅ Real Optuna experiment complete!")
    print(f"Best model achieved {results['test_accuracy']:.4f} test accuracy")