defmodule Mix.Tasks.Scout.Demo do
  use Mix.Task
  
  @shortdoc "Run Scout demonstration"
  
  def run(_args) do
    Mix.Task.run("app.start")
    
    IO.puts("\n" <> String.duplicate("=", 60))
    IO.puts("       Scout - Distributed Hyperparameter Optimization")
    IO.puts("                    Version 0.3")
    IO.puts(String.duplicate("=", 60))
    
    # Demo 1: Random Search
    demo_random_search()
    
    # Demo 2: TPE with Multivariate
    demo_tpe()
    
    # Demo 3: Grid Search
    demo_grid_search()
    
    # Demo 4: ML Hyperparameters
    demo_ml_optimization()
    
    IO.puts("\n" <> String.duplicate("=", 60))
    IO.puts("                    Demo Complete!")
    IO.puts(String.duplicate("=", 60))
    IO.puts("\n✨ Scout Features Demonstrated:")
    IO.puts("   • Random Search - Simple baseline optimization")
    IO.puts("   • TPE with Multivariate - Correlation-aware sampling")
    IO.puts("   • Grid Search - Systematic exploration")
    IO.puts("   • Mixed parameter types - Continuous, log, choice")
    IO.puts("\n🚀 Ready for production use!")
  end
  
  defp demo_random_search do
    IO.puts("\n📊 Demo 1: Random Search Optimization")
    IO.puts("Finding minimum of quadratic function: (x-2)² + (y+3)²")
    
    study = %Scout.Study{
      id: "demo_random_#{System.system_time(:millisecond)}",
      goal: :minimize,
      max_trials: 20,
      parallelism: 1,
      search_space: fn _ix ->
        %{
          x: {:uniform, -10.0, 10.0},
          y: {:uniform, -10.0, 10.0}
        }
      end,
      objective: fn params ->
        x = params[:x] || params["x"]
        y = params[:y] || params["y"]
        (x - 2.0) ** 2 + (y + 3.0) ** 2
      end,
      sampler: Scout.Sampler.Random,
      sampler_opts: %{},
      seed: 42
    }
    
    {:ok, result} = Scout.run(study)
    IO.puts("✅ Best value found: #{Float.round(result.best_score, 4)}")
    IO.puts("   Best params: x=#{Float.round(result.best_params[:x], 2)}, y=#{Float.round(result.best_params[:y], 2)}")
    IO.puts("   Target was: x=2.0, y=-3.0")
  end
  
  defp demo_tpe do
    IO.puts("\n📊 Demo 2: TPE with Multivariate Correlation")
    IO.puts("Optimizing Rosenbrock function")
    
    study = %Scout.Study{
      id: "demo_tpe_#{System.system_time(:millisecond)}",
      goal: :minimize,
      max_trials: 50,
      parallelism: 1,
      search_space: fn _ix ->
        %{
          x: {:uniform, -5.0, 5.0},
          y: {:uniform, -5.0, 5.0}
        }
      end,
      objective: fn params ->
        x = params[:x] || params["x"]
        y = params[:y] || params["y"]
        100 * (y - x ** 2) ** 2 + (1 - x) ** 2
      end,
      sampler: Scout.Sampler.TPE,
      sampler_opts: %{
        gamma: 0.25,
        n_candidates: 24,
        min_obs: 10,
        multivariate: true
      },
      seed: 42
    }
    
    {:ok, result} = Scout.run(study)
    IO.puts("✅ Best value found: #{Float.round(result.best_score, 4)}")
    IO.puts("   Best params: x=#{Float.round(result.best_params[:x], 2)}, y=#{Float.round(result.best_params[:y], 2)}")
    IO.puts("   Target was: x=1.0, y=1.0")
  end
  
  defp demo_grid_search do
    IO.puts("\n📊 Demo 3: Grid Search")
    IO.puts("Systematic parameter exploration")
    
    study = %Scout.Study{
      id: "demo_grid_#{System.system_time(:millisecond)}",
      goal: :minimize,
      max_trials: 16,
      parallelism: 1,
      search_space: fn _ix ->
        %{
          x: {:uniform, -2.0, 2.0},
          y: {:uniform, -2.0, 2.0}
        }
      end,
      objective: fn params ->
        x = params[:x] || params["x"]
        y = params[:y] || params["y"]
        x ** 2 + y ** 2
      end,
      sampler: Scout.Sampler.Grid,
      sampler_opts: %{
        resolution: %{x: 4, y: 4}
      }
    }
    
    {:ok, result} = Scout.run(study)
    IO.puts("✅ Best value found: #{Float.round(result.best_score, 4)}")
    IO.puts("   Best params: x=#{Float.round(result.best_params[:x], 2)}, y=#{Float.round(result.best_params[:y], 2)}")
  end
  
  defp demo_ml_optimization do
    IO.puts("\n📊 Demo 4: ML Hyperparameter Optimization")
    IO.puts("Simulating neural network training")
    
    study = %Scout.Study{
      id: "demo_ml_#{System.system_time(:millisecond)}",
      goal: :minimize,
      max_trials: 30,
      parallelism: 1,
      search_space: fn _ix ->
        %{
          learning_rate: {:log_uniform, 1.0e-5, 1.0e-1},
          dropout: {:uniform, 0.0, 0.5},
          batch_size: {:choice, [16, 32, 64, 128]},
          optimizer: {:choice, ["adam", "sgd", "rmsprop"]}
        }
      end,
      objective: fn params ->
        lr = params[:learning_rate] || params["learning_rate"]
        dropout = params[:dropout] || params["dropout"]
        batch = params[:batch_size] || params["batch_size"]
        opt = params[:optimizer] || params["optimizer"]
        
        base_loss = -:math.log10(lr) * 0.3
        dropout_penalty = abs(dropout - 0.3) * 2
        
        batch_penalty = case batch do
          32 -> 0.0
          64 -> 0.1
          16 -> 0.2
          128 -> 0.3
          _ -> 0.5
        end
        
        optimizer_bonus = case opt do
          "adam" -> -0.2
          "rmsprop" -> 0.0
          "sgd" -> 0.1
          _ -> 0.3
        end
        
        noise = :rand.uniform() * 0.1
        base_loss + dropout_penalty + batch_penalty + optimizer_bonus + noise
      end,
      sampler: Scout.Sampler.TPE,
      sampler_opts: %{
        gamma: 0.25,
        n_candidates: 24,
        min_obs: 10
      }
    }
    
    {:ok, result} = Scout.run(study)
    IO.puts("✅ Best validation loss: #{Float.round(result.best_score, 4)}")
    IO.puts("   Best hyperparameters:")
    IO.puts("   - Learning rate: #{Float.round(result.best_params[:learning_rate], 6)}")
    IO.puts("   - Dropout: #{Float.round(result.best_params[:dropout], 3)}")
    IO.puts("   - Batch size: #{result.best_params[:batch_size]}")
    IO.puts("   - Optimizer: #{result.best_params[:optimizer]}")
  end
end