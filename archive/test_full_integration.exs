#!/usr/bin/env elixir

# Full integration test with TPE sampler and live dashboard
{:ok, _} = Application.ensure_all_started(:scout)

defmodule FullIntegrationTest do
  def objective(params) do
    # Rosenbrock function - minimum at (1, 1) with value 0
    x = params.x
    y = params.y
    score = -((1 - x) ** 2 + 100 * (y - x ** 2) ** 2)
    {:ok, score}
  end
  
  def search_space(_) do
    %{
      x: {:uniform, -2.0, 2.0},
      y: {:uniform, -2.0, 2.0}
    }
  end
end

IO.puts("🚀 FULL INTEGRATION TEST")
IO.puts("Dashboard: http://localhost:4050")
IO.puts("Optimizing Rosenbrock function (minimum at x=1, y=1)")
IO.puts("")

# Create study with TPE sampler
study = %Scout.Study{
  id: "rosenbrock-tpe-#{:os.system_time(:second)}",
  goal: :maximize,
  sampler: :tpe,
  sampler_opts: %{
    min_obs: 10,
    gamma: 0.25,
    n_candidates: 24
  },
  pruner: nil,
  pruner_opts: %{},
  search_space: &FullIntegrationTest.search_space/1,
  objective: &FullIntegrationTest.objective/1,
  max_trials: 100,
  parallelism: 1
}

# Store study
Scout.Store.put_study(study)

IO.puts("Study ID: #{study.id}")
IO.puts("Running 100 trials with TPE sampler...")
IO.puts("")

# Run optimization with telemetry events
history = []
best_score = -999999
best_params = nil

# Subscribe to telemetry events for live updates
:telemetry.attach(
  "test-handler",
  [:scout, :trial, :complete],
  fn [:scout, :trial, :complete], measurements, metadata, _config ->
    score = measurements.score
    if score && score > best_score do
      IO.puts("  ✨ New best: #{Float.round(score, 2)}")
    end
  end,
  nil
)

# Initialize sampler state
sampler_state = Scout.Sampler.TPE.init(study.sampler_opts)

for i <- 1..study.max_trials do
  # Get next parameters from TPE
  {params, sampler_state} = Scout.Sampler.TPE.next(
    study.search_space,
    i,
    history,
    sampler_state
  )
  
  # Evaluate objective
  {:ok, score} = study.objective.(params)
  
  # Create trial
  trial = %Scout.Trial{
    id: "trial-#{i}",
    study_id: study.id,
    params: params,
    bracket: 0,
    score: score,
    status: :succeeded
  }
  
  # Store trial
  Scout.Store.add_trial(study.id, trial)
  
  # Emit telemetry
  :telemetry.execute(
    [:scout, :trial, :complete],
    %{score: score, duration: 10},
    %{study_id: study.id, trial_id: trial.id, params: params}
  )
  
  # Update history and best
  history = history ++ [trial]
  if score > best_score do
    best_score = score
    best_params = params
  end
  
  # Progress indicator every 10 trials
  if rem(i, 10) == 0 and best_params != nil do
    distance = :math.sqrt((best_params.x - 1) ** 2 + (best_params.y - 1) ** 2)
    IO.puts("Trial #{String.pad_leading(Integer.to_string(i), 3)}: Best score = #{Float.round(best_score, 2)}, Distance from optimum = #{Float.round(distance, 3)}")
  end
end

# Final results
IO.puts("")
IO.puts("=" <> String.duplicate("=", 59))
IO.puts("📊 FINAL RESULTS")
IO.puts("")

distance = :math.sqrt((best_params.x - 1) ** 2 + (best_params.y - 1) ** 2)
IO.puts("Best Score: #{Float.round(best_score, 2)}")
IO.puts("Best Parameters: x=#{Float.round(best_params.x, 3)}, y=#{Float.round(best_params.y, 3)}")
IO.puts("Distance from Optimum: #{Float.round(distance, 3)}")

# Check convergence
scores = Enum.map(history, & &1.score)
first_20 = Enum.take(scores, 20)
last_20 = Enum.take(scores, -20)
first_avg = Enum.sum(first_20) / length(first_20)
last_avg = Enum.sum(last_20) / length(last_20)

IO.puts("")
IO.puts("📈 CONVERGENCE ANALYSIS")
IO.puts("First 20 trials avg: #{Float.round(first_avg, 2)}")
IO.puts("Last 20 trials avg: #{Float.round(last_avg, 2)}")

improvement = if first_avg < 0, do: (last_avg - first_avg) / abs(first_avg) * 100, else: 0
IO.puts("Improvement: #{Float.round(improvement, 1)}%")

IO.puts("")
if distance < 0.1 do
  IO.puts("✅ EXCELLENT! TPE found near-optimal solution (within 0.1 units)")
else
  if distance < 0.5 do
    IO.puts("✅ GOOD! TPE found good solution (within 0.5 units)")
  else
    if improvement > 50 do
      IO.puts("✅ TPE showed strong learning (>50% improvement)")
    else
      IO.puts("⚠️  TPE needs more tuning")
    end
  end
end

IO.puts("")
IO.puts("🌐 Check the dashboard at http://localhost:4050")
IO.puts("   You should see the study and trial results there!")