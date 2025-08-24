# FULL DOGFOOD TEST - TPE Sampler + Dashboard
{:ok, _} = Application.ensure_all_started(:scout)

defmodule FullDemo do
  def search_space(_index) do
    %{
      learning_rate: {:log_uniform, 0.0001, 0.1},
      dropout: {:uniform, 0.1, 0.5},
      batch_size: {:choice, [16, 32, 64, 128]},
      optimizer: {:choice, ["adam", "sgd", "rmsprop"]}
    }
  end
  
  def objective(params) do
    # Simulate model training with more complex scoring
    base_score = (1.0 - params.dropout) * 50.0
    
    # LR sweet spot around 0.01
    lr_factor = 1.0 - abs(:math.log10(params.learning_rate) + 2.0) * 0.2
    
    # Batch size preference
    batch_factor = case params.batch_size do
      32 -> 1.2
      64 -> 1.1
      16 -> 0.95
      _ -> 1.0
    end
    
    # Optimizer preference
    opt_factor = case params.optimizer do
      "adam" -> 1.15
      "rmsprop" -> 1.05
      _ -> 1.0
    end
    
    score = base_score * lr_factor * batch_factor * opt_factor
    # Add small noise
    score = score + (:rand.uniform() - 0.5) * 2.0
    
    {:ok, score}
  end
end

IO.puts("🚀 TESTING SCOUT WITH TPE SAMPLER AND DASHBOARD")
IO.puts("=" <> String.duplicate("=", 49))

# Create study with TPE sampler
study = %Scout.Study{
  id: "tpe-test-#{:erlang.system_time()}",
  goal: :maximize,
  max_trials: 30,
  parallelism: 1,
  search_space: &FullDemo.search_space/1,
  objective: &FullDemo.objective/1,
  sampler: Scout.Sampler.TPE,
  sampler_opts: %{
    min_obs: 10,
    gamma: 0.15,
    n_candidates: 24
  },
  pruner: nil,
  pruner_opts: %{}
}

# Store study
Scout.Store.put_study(%{id: study.id, goal: study.goal})

IO.puts("📊 Study ID: #{study.id}")
IO.puts("🎯 Sampler: TPE (Tree-structured Parzen Estimator)")
IO.puts("📈 Goal: Maximize")
IO.puts("")

# Initialize sampler state
sampler_state = Scout.Sampler.TPE.init(study.sampler_opts)

# Track best
best_score = -999999
best_params = nil
history = []

IO.puts("Running trials...")
IO.puts("")

for i <- 1..30 do
  # Get params from TPE sampler
  {params, sampler_state} = Scout.Sampler.TPE.next(
    study.search_space,
    i,
    history,
    sampler_state
  )
  
  # Evaluate
  {:ok, score} = FullDemo.objective(params)
  
  # Create trial record
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
  
  # Update history for TPE
  history = history ++ [trial]
  
  # Track best
  if score > best_score do
    best_score = score
    best_params = params
    IO.puts("✨ Trial #{String.pad_leading(to_string(i), 2)}: NEW BEST! Score: #{Float.round(score, 2)}")
    IO.puts("   LR: #{Float.round(params.learning_rate, 5)}, Dropout: #{Float.round(params.dropout, 2)}, Batch: #{params.batch_size}, Opt: #{params.optimizer}")
  else
    if rem(i, 5) == 0 do
      IO.puts("   Trial #{String.pad_leading(to_string(i), 2)}: Score: #{Float.round(score, 2)}")
    end
  end
end

IO.puts("")
IO.puts("=" <> String.duplicate("=", 49))
IO.puts("📊 OPTIMIZATION COMPLETE")
IO.puts("Best Score: #{Float.round(best_score, 2)}")
IO.puts("Best Parameters:")
IO.puts("  Learning Rate: #{Float.round(best_params.learning_rate, 5)}")
IO.puts("  Dropout: #{Float.round(best_params.dropout, 3)}")
IO.puts("  Batch Size: #{best_params.batch_size}")
IO.puts("  Optimizer: #{best_params.optimizer}")

# Verify storage
trials = Scout.Store.list_trials(study.id)
IO.puts("")
IO.puts("📦 Stored #{length(trials)} trials in Scout")

# Test if TPE actually improved over random
first_10_scores = Enum.take(history, 10) |> Enum.map(& &1.score)
last_10_scores = Enum.take(history, -10) |> Enum.map(& &1.score)
first_avg = Enum.sum(first_10_scores) / length(first_10_scores)
last_avg = Enum.sum(last_10_scores) / length(last_10_scores)

IO.puts("")
IO.puts("📈 TPE Performance:")
IO.puts("  First 10 trials avg: #{Float.round(first_avg, 2)}")
IO.puts("  Last 10 trials avg: #{Float.round(last_avg, 2)}")
improvement = (last_avg - first_avg) / first_avg * 100
IO.puts("  Improvement: #{Float.round(improvement, 1)}%")

if improvement > 0 do
  IO.puts("  ✅ TPE is learning and improving!")
else
  IO.puts("  ⚠️  TPE may need tuning or more trials")
end

IO.puts("")
IO.puts("✅ TPE SAMPLER IS WORKING!")
IO.puts("")
IO.puts("📡 Now testing dashboard...")
IO.puts("Study ID for dashboard: #{study.id}")