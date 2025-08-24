#!/usr/bin/env python3
"""
Advanced Optuna ML Example - Real dogfooding of advanced features
Shows what Scout is missing for serious ML optimization
"""

import optuna
import pandas as pd
import numpy as np
from sklearn.datasets import make_classification
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import cross_val_score, train_test_split
from sklearn.metrics import accuracy_score, f1_score
import sqlite3
import time

def create_realistic_dataset():
    """Create a challenging ML dataset"""
    X, y = make_classification(
        n_samples=5000,
        n_features=50, 
        n_informative=30,
        n_redundant=10,
        n_clusters_per_class=2,
        class_sep=0.8,
        random_state=42
    )
    
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )
    
    print(f"📊 Dataset: {X_train.shape[0]} train, {X_test.shape[0]} test samples")
    print(f"📊 Features: {X_train.shape[1]}, Classes: {len(np.unique(y))}")
    
    return X_train, X_test, y_train, y_test

def advanced_objective_with_pruning(trial):
    """Objective function with intermediate reporting and pruning"""
    
    # Complex hyperparameter space
    n_estimators = trial.suggest_int('n_estimators', 10, 200)
    max_depth = trial.suggest_int('max_depth', 3, 30)
    min_samples_split = trial.suggest_int('min_samples_split', 2, 20)
    min_samples_leaf = trial.suggest_int('min_samples_leaf', 1, 10)
    max_features = trial.suggest_categorical('max_features', ['sqrt', 'log2', None])
    
    # Bootstrap and class balancing
    bootstrap = trial.suggest_categorical('bootstrap', [True, False])
    class_weight = trial.suggest_categorical('class_weight', [None, 'balanced'])
    
    # Create model
    clf = RandomForestClassifier(
        n_estimators=n_estimators,
        max_depth=max_depth,
        min_samples_split=min_samples_split,
        min_samples_leaf=min_samples_leaf,
        max_features=max_features,
        bootstrap=bootstrap,
        class_weight=class_weight,
        random_state=42,
        n_jobs=-1
    )
    
    # Progressive evaluation with pruning
    scores = []
    for fold in range(1, 6):  # 5-fold CV
        # Train on subset for intermediate evaluation
        partial_X = X_train[:len(X_train)//fold*fold]
        partial_y = y_train[:len(y_train)//fold*fold]
        
        fold_scores = cross_val_score(clf, partial_X, partial_y, cv=3, scoring='accuracy')
        intermediate_score = fold_scores.mean()
        scores.append(intermediate_score)
        
        # Report intermediate value for pruning
        trial.report(intermediate_score, fold)
        
        # Check if trial should be pruned
        if trial.should_prune():
            raise optuna.TrialPruned()
    
    # Final evaluation on full dataset
    final_scores = cross_val_score(clf, X_train, y_train, cv=5, scoring='f1')
    return final_scores.mean()

def multi_objective_ml(trial):
    """Multi-objective: Maximize accuracy, minimize model complexity"""
    
    # Hyperparameters
    n_estimators = trial.suggest_int('n_estimators', 10, 100)
    max_depth = trial.suggest_int('max_depth', 3, 15)
    min_samples_split = trial.suggest_int('min_samples_split', 2, 10)
    max_features = trial.suggest_categorical('max_features', ['sqrt', 'log2'])
    
    # Create model
    clf = RandomForestClassifier(
        n_estimators=n_estimators,
        max_depth=max_depth,
        min_samples_split=min_samples_split,
        max_features=max_features,
        random_state=42,
        n_jobs=-1
    )
    
    # Accuracy objective
    scores = cross_val_score(clf, X_train, y_train, cv=3, scoring='f1')
    accuracy = scores.mean()
    
    # Complexity objective (lower is better)
    complexity = n_estimators * max_depth  # Simple complexity metric
    
    return accuracy, -complexity  # Maximize accuracy, minimize complexity

def test_advanced_optuna_features():
    """Test advanced Optuna features that Scout doesn't have"""
    
    print("🚀 Testing Advanced Optuna Features")
    print("=" * 60)
    
    # Feature 1: Persistent storage with study resumption
    print("\n1️⃣ Testing Persistent Storage...")
    storage_url = "sqlite:///advanced_optuna_study.db"
    study_name = "advanced_ml_optimization"
    
    try:
        # Try to load existing study
        study = optuna.load_study(study_name=study_name, storage=storage_url)
        print(f"📂 Resumed existing study with {len(study.trials)} trials")
    except KeyError:
        # Create new study with advanced configuration
        study = optuna.create_study(
            study_name=study_name,
            storage=storage_url,
            direction='maximize',
            sampler=optuna.samplers.TPESampler(
                seed=42,
                n_startup_trials=10,
                n_ei_candidates=24
            ),
            pruner=optuna.pruners.HyperbandPruner(
                min_resource=1,
                max_resource=5,
                reduction_factor=3
            )
        )
        print("🆕 Created new study with TPE + Hyperband")
    
    # Feature 2: Advanced optimization with pruning
    print("\n2️⃣ Running optimization with pruning...")
    start_time = time.time()
    
    def print_callback(study, trial):
        if trial.state == optuna.trial.TrialState.COMPLETE:
            print(f"  Trial {trial.number}: {trial.value:.4f} (completed)")
        elif trial.state == optuna.trial.TrialState.PRUNED:
            print(f"  Trial {trial.number}: PRUNED at step {len(trial.intermediate_values)}")
    
    study.optimize(
        advanced_objective_with_pruning,
        n_trials=30,
        callbacks=[print_callback],
        timeout=120  # 2 minute limit
    )
    
    duration = time.time() - start_time
    
    # Results analysis
    completed_trials = [t for t in study.trials if t.state == optuna.trial.TrialState.COMPLETE]
    pruned_trials = [t for t in study.trials if t.state == optuna.trial.TrialState.PRUNED]
    
    print(f"\n📊 ADVANCED OPTUNA RESULTS (completed in {duration:.1f}s)")
    print("=" * 60)
    print(f"Total trials: {len(study.trials)}")
    print(f"Completed: {len(completed_trials)}")
    print(f"Pruned: {len(pruned_trials)}")
    print(f"Pruning rate: {len(pruned_trials)/len(study.trials)*100:.1f}%")
    print(f"Best F1 score: {study.best_value:.4f}")
    print(f"Best params: {study.best_params}")
    
    # Feature 3: Multi-objective optimization
    print("\n3️⃣ Testing Multi-objective Optimization...")
    mo_study = optuna.create_study(
        directions=['maximize', 'maximize'],  # maximize accuracy, maximize (-complexity)
        sampler=optuna.samplers.NSGAIISampler(seed=42)
    )
    
    mo_study.optimize(multi_objective_ml, n_trials=20)
    
    print(f"Pareto front solutions: {len(mo_study.best_trials)}")
    print("Best trade-offs (accuracy vs complexity):")
    for i, trial in enumerate(mo_study.best_trials[:3]):
        accuracy = trial.values[0]
        complexity = -trial.values[1]  # Convert back to positive
        print(f"  Solution {i+1}: {accuracy:.4f} accuracy, {complexity} complexity")
    
    # Feature 4: Parameter importance analysis
    print("\n4️⃣ Parameter Importance Analysis...")
    if len(completed_trials) > 5:
        try:
            importance = optuna.importance.get_param_importances(study)
            print("Most important parameters:")
            for param, imp in sorted(importance.items(), key=lambda x: x[1], reverse=True)[:5]:
                print(f"  {param}: {imp:.3f}")
        except Exception as e:
            print(f"  Could not compute importance: {e}")
    
    return study

def compare_samplers():
    """Compare different sampling strategies"""
    print("\n5️⃣ Comparing Sampling Strategies...")
    
    samplers = {
        'Random': optuna.samplers.RandomSampler(seed=42),
        'TPE': optuna.samplers.TPESampler(seed=42),
        'CMA-ES': optuna.samplers.CmaEsSampler(seed=42)
    }
    
    results = {}
    
    for name, sampler in samplers.items():
        print(f"\n🎲 Testing {name} sampler...")
        study = optuna.create_study(direction='maximize', sampler=sampler)
        
        # Simple objective for quick comparison
        def simple_objective(trial):
            n_estimators = trial.suggest_int('n_estimators', 10, 100)
            max_depth = trial.suggest_int('max_depth', 3, 15)
            
            clf = RandomForestClassifier(
                n_estimators=n_estimators,
                max_depth=max_depth,
                random_state=42,
                n_jobs=-1
            )
            
            scores = cross_val_score(clf, X_train, y_train, cv=3, scoring='f1')
            return scores.mean()
        
        study.optimize(simple_objective, n_trials=15)
        results[name] = study.best_value
        print(f"  Best {name}: {study.best_value:.4f}")
    
    # Find winner
    best_sampler = max(results.items(), key=lambda x: x[1])
    print(f"\n🏆 Winner: {best_sampler[0]} with {best_sampler[1]:.4f}")

if __name__ == "__main__":
    # Create dataset (global for all functions)
    X_train, X_test, y_train, y_test = create_realistic_dataset()
    
    # Test all advanced features
    study = test_advanced_optuna_features()
    compare_samplers()
    
    print(f"\n✅ Advanced Optuna exploration complete!")
    print(f"Study saved to: sqlite:///advanced_optuna_study.db")
    
    # Final model training
    if study.best_params:
        print(f"\n🎯 Training final model with best parameters...")
        final_clf = RandomForestClassifier(**study.best_params, random_state=42, n_jobs=-1)
        final_clf.fit(X_train, y_train)
        
        test_accuracy = accuracy_score(y_test, final_clf.predict(X_test))
        test_f1 = f1_score(y_test, final_clf.predict(X_test))
        
        print(f"Final test accuracy: {test_accuracy:.4f}")
        print(f"Final test F1 score: {test_f1:.4f}")