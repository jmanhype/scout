#!/usr/bin/env elixir
# REAL DOGFOODING: Using Scout to optimize Scout's own hyperparameters

Mix.install([{:scout, path: "."}])

defmodule DogfoodScout do
  @moduledoc """
  Using Scout to optimize Scout's own TPE sampler hyperparameters.
  This is REAL dogfooding - using the tool on itself.
  """
  
  def run do
    IO.puts("\n🐕 DOGFOODING: Using Scout to optimize Scout\n")
    
    # Start store
    case Scout.Store.ETS.start_link([]) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end
    
    # Objective: Find best TPE params for Rosenbrock optimization
    objective = fn params ->
      # Run a mini-optimization with these TPE params
      gamma = params["gamma"]
      n_candidates = params["n_candidates"] |> round()
      min_obs = params["min_obs"] |> round()
      
      # Create TPE with these params
      tpe_state = Scout.Sampler.TPE.init(%{
        gamma: gamma,
        n_candidates: n_candidates,
        min_obs: min_obs,
        seed: 42
      })
      
      # Run 10 trials on Rosenbrock
      results = for i <- 0..9 do
        {sample, _} = Scout.Sampler.TPE.next(
          fn _ -> %{"x" => {:uniform, -2, 2}, "y" => {:uniform, -1, 3}} end,
          i,
          [],  # No history for first trials
          tpe_state
        )
        
        # Evaluate Rosenbrock
        x = sample["x"] || 0.0
        y = sample["y"] || 0.0
        (1 - x) ** 2 + 100 * (y - x ** 2) ** 2
      end
      
      # Return mean performance
      Enum.sum(results) / length(results)
    end
    
    # Search space for TPE hyperparameters
    space = %{
      "gamma" => {:uniform, 0.1, 0.5},        # Good/bad split ratio
      "n_candidates" => {:uniform, 10, 100},  # Candidates to evaluate
      "min_obs" => {:uniform, 5, 20}          # Minimum observations before TPE
    }
    
    # Create study
    study_id = "optimize-tpe-params"
    :ok = Scout.Store.put_study(%{
      id: study_id,
      goal: :minimize,
      max_trials: 20
    })
    
    # Use Random sampler (since TPE might be broken)
    sampler = Scout.Sampler.Random.init(%{seed: 123})
    
    IO.puts("Optimizing TPE hyperparameters...")
    IO.puts("Search space:")
    IO.puts("  gamma: [0.1, 0.5]")
    IO.puts("  n_candidates: [10, 100]")
    IO.puts("  min_obs: [5, 20]")
    IO.puts("")
    
    best_value = :infinity
    best_params = nil
    
    for i <- 1..20 do
      # Get next params
      {params, _} = Scout.Sampler.Random.next(
        fn _ -> space end,
        i - 1,
        [],
        sampler
      )
      
      # Evaluate
      value = objective.(params)
      
      # Track best
      if value < best_value do
        best_value = value
        best_params = params
        IO.puts("Trial #{i}: New best = #{Float.round(value, 2)}")
      end
      
      # Store trial
      Scout.Store.add_trial(study_id, %{
        id: "trial-#{i}",
        params: params,
        value: value,
        status: :completed
      })
    end
    
    IO.puts("\n🏆 BEST TPE HYPERPARAMETERS FOUND:")
    IO.puts("  gamma: #{Float.round(best_params["gamma"], 3)}")
    IO.puts("  n_candidates: #{round(best_params["n_candidates"])}")
    IO.puts("  min_obs: #{round(best_params["min_obs"])}")
    IO.puts("  Performance: #{Float.round(best_value, 2)}")
    
    # Now test if the optimized params actually work
    IO.puts("\n🧪 TESTING OPTIMIZED PARAMS...")
    test_optimized_tpe(best_params)
  end
  
  defp test_optimized_tpe(params) do
    # Test the optimized TPE on a different function (Ackley)
    ackley = fn p ->
      x = p["x"]
      y = p["y"]
      -20 * :math.exp(-0.2 * :math.sqrt(0.5 * (x*x + y*y))) -
      :math.exp(0.5 * (:math.cos(2*:math.pi()*x) + :math.cos(2*:math.pi()*y))) +
      :math.exp(1) + 20
    end
    
    space = %{"x" => {:uniform, -5, 5}, "y" => {:uniform, -5, 5}}
    
    # Create optimized TPE
    tpe = Scout.Sampler.TPE.init(%{
      gamma: params["gamma"],
      n_candidates: round(params["n_candidates"]),
      min_obs: round(params["min_obs"]),
      seed: 999
    })
    
    # Run 30 trials
    best = :infinity
    history = []
    
    for i <- 0..29 do
      {sample, _} = Scout.Sampler.TPE.next(fn _ -> space end, i, history, tpe)
      value = ackley.(sample)
      best = min(best, value)
      
      # Build history for TPE
      history = history ++ [%{params: sample, score: value}]
    end
    
    IO.puts("Ackley function optimization:")
    IO.puts("  Best found: #{Float.round(best, 6)}")
    IO.puts("  (Optimal is 0.0 at x=0, y=0)")
    
    if best < 1.0 do
      IO.puts("  ✅ Optimized TPE works well!")
    else
      IO.puts("  ⚠️  Optimized TPE needs improvement")
    end
  end
end

DogfoodScout.run()