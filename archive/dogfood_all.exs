#!/usr/bin/env elixir

# COMPLETE DOGFOOD TEST - TPE + Dashboard
IO.puts("🚀 SCOUT DOGFOOD TEST - TPE SAMPLER + DASHBOARD")
IO.puts("=" <> String.duplicate("=", 49))
IO.puts("")

# Start Scout application
{:ok, _} = Application.ensure_all_started(:scout)

# Start dashboard in background
spawn(fn ->
  IO.puts("📡 Starting dashboard server on http://localhost:4050...")
  
  # Configure endpoint
  Application.put_env(:scout, ScoutDashboardWeb.Endpoint,
    url: [host: "localhost"],
    secret_key_base: String.duplicate("a", 64),
    render_errors: [view: ScoutDashboardWeb.ErrorView, accepts: ~w(html json)],
    pubsub_server: Scout.PubSub,
    live_view: [signing_salt: "aaaaaaaa"],
    http: [port: 4050],
    server: true,
    adapter: Bandit.PhoenixAdapter
  )
  
  # Start Phoenix apps
  {:ok, _} = Application.ensure_all_started(:phoenix)
  {:ok, _} = Application.ensure_all_started(:phoenix_live_view)
  
  # Start endpoint
  {:ok, _} = ScoutDashboardWeb.Endpoint.start_link()
  
  IO.puts("✅ Dashboard running at http://localhost:4050")
  
  # Keep alive
  Process.sleep(:infinity)
end)

# Give dashboard time to start
Process.sleep(2000)

defmodule OptimizationDemo do
  def search_space(_index) do
    %{
      learning_rate: {:log_uniform, 0.0001, 0.1},
      dropout: {:uniform, 0.1, 0.5},
      batch_size: {:choice, [16, 32, 64, 128]},
      layers: {:int, 1, 5}
    }
  end
  
  def objective(params) do
    # Simulate a neural network performance metric
    # Optimal around: lr=0.01, dropout=0.2, batch=32, layers=3
    
    # Learning rate component (best around 0.01)
    lr_score = 10.0 * :math.exp(-:math.pow(:math.log10(params.learning_rate) + 2.0, 2))
    
    # Dropout component (best around 0.2)
    dropout_score = 10.0 * :math.exp(-:math.pow((params.dropout - 0.2) * 5, 2))
    
    # Batch size component (prefer 32)
    batch_score = case params.batch_size do
      32 -> 10.0
      64 -> 8.0
      16 -> 7.0
      _ -> 5.0
    end
    
    # Layers component (best at 3)
    layers_score = 10.0 * :math.exp(-:math.pow((params.layers - 3) * 0.5, 2))
    
    # Combined score with some noise
    base_score = (lr_score + dropout_score + batch_score + layers_score) / 4.0
    noise = (:rand.uniform() - 0.5) * 0.5
    score = max(0.0, base_score + noise)
    
    # Simulate training time
    Process.sleep(100)
    
    {:ok, score}
  end
end

# Create study
study_id = "dogfood-tpe-#{:erlang.system_time(:millisecond)}"

study = %Scout.Study{
  id: study_id,
  goal: :maximize,
  max_trials: 30,
  parallelism: 1,
  search_space: &OptimizationDemo.search_space/1,
  objective: &OptimizationDemo.objective/1,
  sampler: Scout.Sampler.TPE,
  sampler_opts: %{
    min_obs: 10,
    gamma: 0.25,
    n_candidates: 24,
    goal: :maximize
  },
  pruner: nil,
  pruner_opts: %{}
}

# Store study
Scout.Store.put_study(%{id: study.id, goal: study.goal})

IO.puts("📊 OPTIMIZATION DETAILS:")
IO.puts("  Study ID: #{study.id}")
IO.puts("  Sampler: TPE (Tree-structured Parzen Estimator)")
IO.puts("  Trials: 30")
IO.puts("  Dashboard: http://localhost:4050")
IO.puts("")
IO.puts("  Navigate to dashboard and enter Study ID: #{study.id}")
IO.puts("")

# Initialize TPE
sampler_state = Scout.Sampler.TPE.init(study.sampler_opts)

# Track progress
history = []
best_score = 0.0
best_params = nil
scores = []

IO.puts("Running optimization...")
IO.puts("")

for i <- 1..30 do
  # Get hyperparameters from TPE
  {params, sampler_state} = Scout.Sampler.TPE.next(
    study.search_space,
    i,
    history,
    sampler_state
  )
  
  # Evaluate objective
  {:ok, score} = OptimizationDemo.objective(params)
  scores = scores ++ [score]
  
  # Create trial
  trial = %Scout.Trial{
    id: "trial-#{i}",
    study_id: study.id,
    params: params,
    bracket: 0,
    score: score,
    status: :succeeded,
    started_at: DateTime.utc_now(),
    finished_at: DateTime.utc_now()
  }
  
  # Store trial
  Scout.Store.add_trial(study.id, trial)
  
  # Update history
  history = history ++ [trial]
  
  # Track best
  if score > best_score do
    best_score = score
    best_params = params
    IO.puts("✨ Trial #{String.pad_leading(Integer.to_string(i), 2)}: NEW BEST! Score: #{Float.round(score, 3)}")
    IO.puts("   LR: #{:io_lib.format("~.5f", [params.learning_rate])}, Dropout: #{Float.round(params.dropout, 2)}, Batch: #{params.batch_size}, Layers: #{params.layers}")
  else
    if rem(i, 5) == 0 do
      IO.puts("   Trial #{String.pad_leading(Integer.to_string(i), 2)}: Score: #{Float.round(score, 3)}")
    end
  end
end

# Analysis
IO.puts("")
IO.puts("=" <> String.duplicate("=", 49))
IO.puts("📊 OPTIMIZATION RESULTS")
IO.puts("")

IO.puts("Best Score: #{Float.round(best_score, 3)}")
IO.puts("Best Parameters:")
IO.puts("  Learning Rate: #{:io_lib.format("~.5f", [best_params.learning_rate])}")
IO.puts("  Dropout: #{Float.round(best_params.dropout, 3)}")  
IO.puts("  Batch Size: #{best_params.batch_size}")
IO.puts("  Layers: #{best_params.layers}")

# Check convergence
first_10 = Enum.take(scores, 10)
last_10 = Enum.take(scores, -10)
first_avg = Enum.sum(first_10) / length(first_10)
last_avg = Enum.sum(last_10) / length(last_10)

IO.puts("")
IO.puts("📈 TPE Performance Analysis:")
IO.puts("  First 10 trials average: #{Float.round(first_avg, 3)}")
IO.puts("  Last 10 trials average: #{Float.round(last_avg, 3)}")

improvement = if first_avg > 0, do: (last_avg - first_avg) / first_avg * 100, else: 0
IO.puts("  Improvement: #{Float.round(improvement, 1)}%")

if improvement > 10 do
  IO.puts("  ✅ TPE successfully optimized! (#{Float.round(improvement, 0)}% improvement)")
elsif improvement > 0 do
  IO.puts("  ✅ TPE showed improvement")
else
  IO.puts("  ⚠️  TPE may need more trials or tuning")
end

# Verify storage
trials = Scout.Store.list_trials(study.id)
IO.puts("")
IO.puts("📦 Storage Verification:")
IO.puts("  Trials stored: #{length(trials)}")

{:ok, study_data} = Scout.Store.get_study(study.id)
IO.puts("  Study retrieved: ✓")

IO.puts("")
IO.puts("=" <> String.duplicate("=", 49))
IO.puts("✅ DOGFOOD TEST COMPLETE!")
IO.puts("")
IO.puts("📡 Dashboard: http://localhost:4050")
IO.puts("📝 Study ID: #{study.id}")
IO.puts("")
IO.puts("Visit the dashboard and enter the Study ID to see visualizations!")
IO.puts("Press Ctrl+C to stop...")
IO.puts("")

# Keep running for dashboard
Process.sleep(:infinity)