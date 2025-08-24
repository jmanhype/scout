# Real ML Study using Scout - Like Optuna's advanced_ml.py

defmodule RealScoutMLStudy do
  @moduledoc """
  Production-style ML hyperparameter optimization using Scout.
  This is Scout's equivalent to the advanced Optuna example I ran.
  """

  # Study callbacks for durable execution (required by Oban)
  def search_space(_ix) do
    %{
      # Neural network architecture
      n_layers: {:int, 2, 6},
      hidden_size: {:int, 32, 256},
      dropout_rate: {:uniform, 0.1, 0.5},
      
      # Training hyperparameters  
      learning_rate: {:log_uniform, 1.0e-4, 1.0e-1},
      batch_size: {:int, 16, 128},
      
      # Optimization settings
      optimizer: {:choice, ["adam", "sgd", "rmsprop"]},
      weight_decay: {:log_uniform, 1.0e-6, 1.0e-2},
      
      # Regularization
      batch_norm: {:choice, [true, false]},
      activation: {:choice, ["relu", "tanh", "elu"]}
    }
  end

  # Iterative objective with pruning (2-arity for early stopping)
  def objective(params, report_fn) do
    # Simulate neural network training over multiple epochs
    simulate_ml_training(params, report_fn)
  end

  defp simulate_ml_training(params, report_fn) do
    # Simulate realistic ML performance based on hyperparameters
    base_accuracy = 0.75
    
    # Architecture impact
    arch_boost = case {params.n_layers, params.hidden_size} do
      {n, h} when n >= 3 and n <= 4 and h >= 64 and h <= 128 -> 0.08
      {n, h} when n >= 2 and h >= 32 -> 0.04
      _ -> -0.02
    end
    
    # Learning rate impact (sweet spot around 0.001-0.01)
    lr_boost = cond do
      params.learning_rate >= 0.001 and params.learning_rate <= 0.01 -> 0.06
      params.learning_rate >= 0.0001 and params.learning_rate <= 0.1 -> 0.02
      true -> -0.04
    end
    
    # Optimizer impact
    opt_boost = case params.optimizer do
      "adam" -> 0.04
      "sgd" -> 0.01
      _ -> 0.02
    end
    
    # Regularization impact
    reg_boost = if params.dropout_rate > 0.2 and params.dropout_rate < 0.4 do
      0.03
    else
      -0.01
    end
    
    # Batch norm boost
    bn_boost = if params.batch_norm, do: 0.02, else: 0.0
    
    # Calculate base performance (what model could achieve)
    potential_accuracy = base_accuracy + arch_boost + lr_boost + opt_boost + reg_boost + bn_boost
    potential_accuracy = max(0.60, min(0.95, potential_accuracy))
    
    # Simulate training over 10 epochs with early stopping opportunity
    max_epochs = 10
    
    # Learning curve shape depends on hyperparameters
    learning_curve_noise = 0.02
    convergence_rate = case params.learning_rate do
      lr when lr > 0.01 -> 0.6  # Fast but unstable
      lr when lr > 0.001 -> 0.8  # Good convergence
      _ -> 0.9  # Slow but steady
    end
    
    # Simulate epoch-by-epoch training
    Enum.reduce_while(1..max_epochs, 0.0, fn epoch, _prev_acc ->
      # Simulate progressive improvement with noise
      progress = :math.pow(epoch / max_epochs, convergence_rate)
      epoch_accuracy = potential_accuracy * progress + (:rand.uniform() - 0.5) * learning_curve_noise
      epoch_accuracy = max(0.5, min(0.95, epoch_accuracy))
      
      # Report intermediate result for pruning
      case report_fn.(epoch_accuracy, epoch - 1) do  # 0-indexed rung
        :prune -> 
          {:halt, {:pruned, epoch_accuracy}}
        :continue -> 
          if epoch == max_epochs do
            {:halt, {:completed, epoch_accuracy}}
          else
            {:cont, epoch_accuracy}
          end
      end
    end)
    |> case do
      {:completed, final_accuracy} -> final_accuracy
      {:pruned, final_accuracy} -> final_accuracy  # Return partial result
    end
  end
end