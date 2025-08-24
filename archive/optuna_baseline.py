#!/usr/bin/env python3
"""
OPTUNA BASELINE TEST
Run identical optimization problems with Optuna to establish ground truth.
Then we'll replicate exactly the same in Scout and compare.
"""

import optuna
import numpy as np
import time
from typing import Dict, Any
import json

class OptunaBaseline:
    def __init__(self):
        self.results = {}
    
    def ml_hyperparameter_objective(self, trial):
        """
        Simulate XGBoost hyperparameter optimization
        This is a realistic ML use case we'll replicate in Scout
        """
        learning_rate = trial.suggest_float("learning_rate", 0.001, 0.3, log=True)
        max_depth = trial.suggest_int("max_depth", 3, 10)
        n_estimators = trial.suggest_int("n_estimators", 50, 300)
        subsample = trial.suggest_float("subsample", 0.5, 1.0)
        colsample_bytree = trial.suggest_float("colsample_bytree", 0.5, 1.0)
        
        # Simulated accuracy (optimal around lr=0.1, depth=6, n_est=100)
        lr_score = -abs(np.log10(learning_rate) + 1.0)
        depth_score = -abs(max_depth - 6) * 0.05
        n_est_score = -abs(n_estimators - 100) * 0.001
        subsample_score = -abs(subsample - 0.8) * 0.1
        colsample_score = -abs(colsample_bytree - 0.8) * 0.1
        
        accuracy = 0.8 + lr_score + depth_score + n_est_score + subsample_score + colsample_score
        return max(0.0, min(1.0, accuracy))
    
    def multi_objective_function(self, trial):
        """
        Multi-objective optimization: Accuracy vs Inference Time
        """
        n_estimators = trial.suggest_int("n_estimators", 10, 200)
        max_depth = trial.suggest_int("max_depth", 2, 20)
        
        complexity = n_estimators * max_depth / 100.0
        accuracy = 0.7 + 0.3 * (1 - np.exp(-complexity))
        inference_time = 0.1 + complexity * 0.5
        
        return accuracy, inference_time
    
    def conditional_optimizer_objective(self, trial):
        """
        Conditional search space: Different optimizers with different hyperparameters
        """
        optimizer = trial.suggest_categorical("optimizer", ["adam", "sgd", "rmsprop"])
        
        if optimizer == "adam":
            lr = trial.suggest_float("adam_lr", 0.0001, 0.01, log=True)
            beta1 = trial.suggest_float("adam_beta1", 0.8, 0.95)
            beta2 = trial.suggest_float("adam_beta2", 0.99, 0.9999)
            
            score = (-abs(np.log10(lr) + 3.0) * 0.5 +
                    -abs(beta1 - 0.9) * 2.0 +
                    -abs(beta2 - 0.999) * 10.0)
        elif optimizer == "sgd":
            lr = trial.suggest_float("sgd_lr", 0.001, 0.1, log=True)
            momentum = trial.suggest_float("sgd_momentum", 0.8, 0.95)
            
            score = (-abs(np.log10(lr) + 2.0) * 0.5 +
                    -abs(momentum - 0.9) * 2.0)
        else:  # rmsprop
            lr = trial.suggest_float("rmsprop_lr", 0.0001, 0.01, log=True)
            decay = trial.suggest_float("rmsprop_decay", 0.8, 0.95)
            
            score = (-abs(np.log10(lr) + 3.0) * 0.5 +
                    -abs(decay - 0.9) * 2.0)
        
        return score + 1.0  # Shift to positive
    
    def rastrigin_objective(self, trial):
        """
        Rastrigin function: Standard optimization benchmark
        Global minimum at (0, 0) with value 0
        """
        x = trial.suggest_float("x", -5.12, 5.12)
        y = trial.suggest_float("y", -5.12, 5.12)
        
        result = 20 + x*x - 10*np.cos(2*np.pi*x) + y*y - 10*np.cos(2*np.pi*y)
        return result  # Minimize
    
    def run_test(self, test_name: str, objective_func, n_trials: int = 50, 
                direction: str = "maximize", **study_kwargs):
        """Run a single test and collect results"""
        print(f"\n🔬 Running {test_name}")
        print("─" * 60)
        
        study = optuna.create_study(direction=direction, **study_kwargs)
        
        start_time = time.time()
        study.optimize(objective_func, n_trials=n_trials)
        end_time = time.time()
        
        # Collect results
        result = {
            "test_name": test_name,
            "n_trials": n_trials,
            "direction": direction,
            "execution_time": end_time - start_time,
            "best_value": study.best_value,
            "best_params": study.best_params,
            "n_completed_trials": len([t for t in study.trials if t.state == optuna.trial.TrialState.COMPLETE]),
            "convergence_data": []
        }
        
        # Track convergence
        best_so_far = float('-inf') if direction == "maximize" else float('inf')
        for i, trial in enumerate(study.trials):
            if trial.state == optuna.trial.TrialState.COMPLETE:
                if direction == "maximize":
                    best_so_far = max(best_so_far, trial.value)
                else:
                    best_so_far = min(best_so_far, trial.value)
                
                result["convergence_data"].append({
                    "trial": i + 1,
                    "value": trial.value,
                    "best_so_far": best_so_far,
                    "params": trial.params
                })
        
        self.results[test_name] = result
        
        # Print summary
        print(f"Best value: {result['best_value']:.6f}")
        print(f"Best params: {result['best_params']}")
        print(f"Execution time: {result['execution_time']:.2f}s")
        print(f"Completed trials: {result['n_completed_trials']}/{n_trials}")
        
        return result
    
    def run_all_tests(self):
        """Run comprehensive test suite"""
        print("╔═══════════════════════════════════════════════════════════════════╗")
        print("║                    OPTUNA BASELINE TESTS                          ║")
        print("║              (Ground Truth for Scout Comparison)                  ║")
        print("╚═══════════════════════════════════════════════════════════════════╝")
        
        # Test 1: Basic TPE on ML hyperparameters
        self.run_test(
            "basic_tpe_ml",
            self.ml_hyperparameter_objective,
            n_trials=30,
            direction="maximize",
            sampler=optuna.samplers.TPESampler(n_startup_trials=10)
        )
        
        # Test 2: Conditional search spaces
        self.run_test(
            "conditional_spaces",
            self.conditional_optimizer_objective,
            n_trials=25,
            direction="maximize",
            sampler=optuna.samplers.TPESampler(multivariate=True, group=True)
        )
        
        # Test 3: Multi-objective optimization
        try:
            multi_obj_study = optuna.create_study(
                directions=["maximize", "minimize"],
                sampler=optuna.samplers.NSGAIISampler()
            )
            
            print(f"\n🔬 Running multi_objective")
            print("─" * 60)
            
            start_time = time.time()
            multi_obj_study.optimize(self.multi_objective_function, n_trials=20)
            end_time = time.time()
            
            # Get Pareto front
            pareto_front = []
            for trial in multi_obj_study.trials:
                if trial.state == optuna.trial.TrialState.COMPLETE:
                    is_dominated = False
                    for other in multi_obj_study.trials:
                        if (other.state == optuna.trial.TrialState.COMPLETE and 
                            other != trial):
                            # Check dominance (maximize accuracy, minimize time)
                            if (other.values[0] >= trial.values[0] and 
                                other.values[1] <= trial.values[1] and
                                (other.values[0] > trial.values[0] or 
                                 other.values[1] < trial.values[1])):
                                is_dominated = True
                                break
                    
                    if not is_dominated:
                        pareto_front.append({
                            "params": trial.params,
                            "accuracy": trial.values[0],
                            "inference_time": trial.values[1]
                        })
            
            self.results["multi_objective"] = {
                "test_name": "multi_objective",
                "n_trials": 20,
                "execution_time": end_time - start_time,
                "pareto_front_size": len(pareto_front),
                "pareto_front": pareto_front
            }
            
            print(f"Pareto front size: {len(pareto_front)}")
            print(f"Sample solutions:")
            for i, sol in enumerate(pareto_front[:3]):
                print(f"  {i+1}: acc={sol['accuracy']:.3f}, time={sol['inference_time']:.3f}")
        
        except Exception as e:
            print(f"Multi-objective test failed: {e}")
        
        # Test 4: Convergence benchmark (Rastrigin)
        self.run_test(
            "rastrigin_benchmark",
            self.rastrigin_objective,
            n_trials=50,
            direction="minimize",
            sampler=optuna.samplers.TPESampler(n_startup_trials=10)
        )
        
        # Test 5: Multivariate TPE
        self.run_test(
            "multivariate_tpe",
            self.ml_hyperparameter_objective,
            n_trials=30,
            direction="maximize", 
            sampler=optuna.samplers.TPESampler(multivariate=True, n_startup_trials=10)
        )
    
    def save_results(self, filename: str = "optuna_baseline_results.json"):
        """Save results for Scout comparison"""
        with open(filename, 'w') as f:
            json.dump(self.results, f, indent=2)
        print(f"\n💾 Results saved to {filename}")
    
    def print_summary(self):
        """Print comprehensive summary"""
        print("\n")
        print("╔═══════════════════════════════════════════════════════════════════╗")
        print("║                        OPTUNA BASELINE SUMMARY                    ║")
        print("╚═══════════════════════════════════════════════════════════════════╝")
        
        for test_name, result in self.results.items():
            if test_name == "multi_objective":
                print(f"📊 {test_name:20} | Pareto front: {result['pareto_front_size']} solutions")
            else:
                print(f"📊 {test_name:20} | Best: {result['best_value']:.6f}")

if __name__ == "__main__":
    baseline = OptunaBaseline()
    baseline.run_all_tests()
    baseline.save_results()
    baseline.print_summary()
    
    print("\n🎯 Next step: Run identical tests in Scout and compare results!")