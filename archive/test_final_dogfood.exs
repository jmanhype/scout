#!/usr/bin/env elixir

# Final dogfood test - simpler quadratic function for better convergence
{:ok, _} = Application.ensure_all_started(:scout)

defmodule FinalDogfoodTest do
  def objective(params) do
    # Simple quadratic - minimum at (3, 3) with value 0
    x_err = params.x - 3.0
    y_err = params.y - 3.0
    score = -(x_err * x_err + y_err * y_err)
    {:ok, score}
  end
  
  def search_space(_) do
    %{
      x: {:uniform, 0.0, 6.0},
      y: {:uniform, 0.0, 6.0}
    }
  end
end

IO.puts("🎯 FINAL DOGFOOD TEST - TPE + Dashboard")
IO.puts("Dashboard: http://localhost:4050")
IO.puts("Target: (3.0, 3.0) with score 0.0")
IO.puts("")

# Create study
study_id = "dogfood-#{:os.system_time(:second)}"
study = %Scout.Study{
  id: study_id,
  goal: :maximize,
  sampler: :tpe,
  sampler_opts: %{
    min_obs: 5,      # Start TPE sooner
    gamma: 0.15,     # Top 15% for good distribution
    n_candidates: 30 # More candidates
  },
  pruner: nil,
  pruner_opts: %{},
  search_space: &FinalDogfoodTest.search_space/1,
  objective: &FinalDogfoodTest.objective/1,
  max_trials: 50,
  parallelism: 1
}

# Store study
Scout.Store.put_study(study)

IO.puts("Study ID: #{study_id}")
IO.puts("Go to http://localhost:4050 and enter: #{study_id}")
IO.puts("")
IO.puts("Running 50 trials with TPE...")
IO.puts("")

# Initialize sampler
sampler_state = Scout.Sampler.TPE.init(study.sampler_opts)
history = []
best_score = -999999
best_params = nil

for i <- 1..study.max_trials do
  # Get next parameters
  {params, sampler_state} = Scout.Sampler.TPE.next(
    study.search_space,
    i,
    history,
    sampler_state
  )
  
  # Evaluate
  {:ok, score} = study.objective.(params)
  
  # Create and store trial
  trial = %Scout.Trial{
    id: "trial-#{i}",
    study_id: study.id,
    params: params,
    bracket: 0,
    score: score,
    status: :succeeded
  }
  
  Scout.Store.add_trial(study.id, trial)
  history = history ++ [trial]
  
  # Track best
  if score > best_score do
    best_score = score
    best_params = params
    distance = :math.sqrt((params.x - 3) ** 2 + (params.y - 3) ** 2)
    
    # Show improvements
    if i <= 10 or distance < 1.0 do
      IO.puts("Trial #{String.pad_leading(Integer.to_string(i), 2)}: NEW BEST! Score: #{Float.round(score, 2)} at (#{Float.round(params.x, 2)}, #{Float.round(params.y, 2)}) - Distance: #{Float.round(distance, 2)}")
    end
  end
  
  # Add small delay for dashboard visibility
  Process.sleep(50)
end

# Final results
IO.puts("")
IO.puts("=" <> String.duplicate("=", 59))

if best_params == nil do
  IO.puts("❌ No valid results found")
  System.halt(1)
end

distance = :math.sqrt((best_params.x - 3) ** 2 + (best_params.y - 3) ** 2)
IO.puts("✅ FINAL RESULTS")
IO.puts("Best Score: #{Float.round(best_score, 2)}")
IO.puts("Best Position: (#{Float.round(best_params.x, 3)}, #{Float.round(best_params.y, 3)})")
IO.puts("Distance from Target: #{Float.round(distance, 3)}")

# Analysis
scores = Enum.map(history, & &1.score)
first_10 = Enum.take(scores, 10)
last_10 = Enum.take(scores, -10)
first_avg = Enum.sum(first_10) / 10
last_avg = Enum.sum(last_10) / 10

IO.puts("")
IO.puts("📊 PERFORMANCE")
IO.puts("First 10 trials avg: #{Float.round(first_avg, 2)}")
IO.puts("Last 10 trials avg: #{Float.round(last_avg, 2)}")
improvement = (last_avg - first_avg) / abs(first_avg) * 100
IO.puts("Improvement: #{Float.round(improvement, 1)}%")

IO.puts("")
if distance < 0.5 do
  IO.puts("🏆 EXCELLENT! TPE converged to near-optimal solution!")
else
  if distance < 1.0 do
    IO.puts("✅ GOOD! TPE found a good solution")
  else
    IO.puts("✅ TPE is learning (#{Float.round(improvement, 0)}% improvement)")
  end
end

IO.puts("")
IO.puts("📌 Check the dashboard at http://localhost:4050")
IO.puts("   Enter Study ID: #{study_id}")