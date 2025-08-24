defmodule DemoStudy do
  def search_space(_trial_index) do
    %{
      learning_rate: {:log_uniform, 1.0e-5, 1.0e-1},
      dropout: {:uniform, 0.1, 0.5},
      batch_size: {:choice, [16, 32, 64, 128]},
      optimizer: {:choice, ["adam", "sgd", "rmsprop"]}
    }
  end

  def objective(params, report_fn) do
    # Simulate training with intermediate reports
    for epoch <- 1..10 do
      # Simulate epoch training
      Process.sleep(100)
      
      # Calculate intermediate score (simulated)
      loss = 1.0 / (1.0 + epoch * params.learning_rate)
      accuracy = 1.0 - loss * params.dropout
      
      # Report intermediate value for pruning
      report_fn.(epoch, accuracy)
    end
    
    # Final score
    final_score = :rand.uniform() * (1.0 - params.dropout) + params.learning_rate
    {:ok, final_score}
  end
end