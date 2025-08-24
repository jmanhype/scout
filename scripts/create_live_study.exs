#!/usr/bin/env elixir

Mix.install([
  {:scout, path: "."}
])

# Start a real optimization study that the dashboard can display
defmodule LiveStudyDemo do
  def run do
    IO.puts "🚀 Creating live study for dashboard demonstration..."
    
    # Define an optimization problem
    objective = fn params ->
      # Simulate neural network training
      x = params.learning_rate
      y = params.batch_size / 100.0  # Normalize batch size
      
      # Add some computation time to simulate real ML training
      Process.sleep(200)
      
      # Rosenbrock-like function with noise (typical ML loss surface)
      loss = (1.0 - x) ** 2 + 100.0 * (y - x ** 2) ** 2 + :rand.uniform() * 0.1
      
      IO.puts "Trial: lr=#{Float.round(x, 6)}, batch=#{round(params.batch_size)}, loss=#{Float.round(loss, 4)}"
      loss
    end
    
    search_space = %{
      learning_rate: {:log_uniform, 0.0001, 0.1},
      batch_size: {:int, 16, 128}
    }
    
    # Start optimization in background process so we can see dashboard updates
    parent = self()
    
    spawn_link(fn ->
      try do
        result = Scout.Easy.optimize(
          objective,
          search_space,
          study_id: "live-dashboard-demo",
          n_trials: 25,
          sampler: :tpe,
          pruner: :median,
          parallelism: 2  # Two concurrent trials
        )
        
        send(parent, {:optimization_complete, result})
      rescue
        error ->
          send(parent, {:optimization_error, error})
      end
    end)
    
    IO.puts """
    ✅ Study started!
    
    Dashboard URLs:
    • Home: http://localhost:4050
    • Study: http://localhost:4050/studies/live-dashboard-demo
    
    The study will run 25 trials with TPE sampler and median pruner.
    Check the dashboard to see real-time updates!
    """
    
    # Wait for completion or timeout
    receive do
      {:optimization_complete, result} ->
        IO.puts "\n🎊 Optimization completed!"
        IO.puts "Best score: #{result.best_value}"
        IO.puts "Best params: #{inspect(result.best_params)}"
        
      {:optimization_error, error} ->
        IO.puts "\n❌ Optimization failed: #{inspect(error)}"
        
    after
      60_000 ->  # 60 second timeout
        IO.puts "\n⏰ Demo timeout reached (study continues in background)"
    end
    
    IO.puts "\nStudy 'live-dashboard-demo' is now available in the dashboard!"
  end
end

# Run the demo
LiveStudyDemo.run()