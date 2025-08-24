#!/usr/bin/env elixir

# Test fixed TPE convergence
{:ok, _} = Application.ensure_all_started(:scout)

defmodule TPEConvergenceTest do
  def objective(params) do
    # Simple quadratic - minimum at (5, 5) with value 0
    x_err = params.x - 5.0
    y_err = params.y - 5.0
    score = -(x_err * x_err + y_err * y_err)
    {:ok, score}
  end
  
  def search_space(_) do
    %{
      x: {:uniform, 0.0, 10.0},
      y: {:uniform, 0.0, 10.0}
    }
  end
end

IO.puts("🧪 TESTING FIXED TPE CONVERGENCE")
IO.puts("Target: (5.0, 5.0) with score 0.0")
IO.puts("")

# Initialize TPE
state = Scout.Sampler.TPE.init(%{
  min_obs: 10,
  gamma: 0.25,
  n_candidates: 24,
  goal: :maximize
})

history = []
best = -999999
best_params = nil
scores = []

for i <- 1..50 do
  {params, state} = Scout.Sampler.TPE.next(
    &TPEConvergenceTest.search_space/1,
    i,
    history,
    state
  )
  
  {:ok, score} = TPEConvergenceTest.objective(params)
  scores = scores ++ [score]
  
  trial = %Scout.Trial{
    id: "trial-#{i}",
    study_id: "test",
    params: params,
    bracket: 0,
    score: score,
    status: :succeeded
  }
  history = history ++ [trial]
  
  if score > best do
    best = score
    best_params = params
    if i <= 20 or rem(i, 5) == 0 do
      distance = :math.sqrt(:math.pow(params.x - 5.0, 2) + :math.pow(params.y - 5.0, 2))
      IO.puts("Trial #{String.pad_leading(Integer.to_string(i), 2)}: NEW BEST! Score: #{Float.round(score, 2)} at (#{Float.round(params.x, 2)}, #{Float.round(params.y, 2)}) - Distance: #{Float.round(distance, 2)}")
    end
  end
end

IO.puts("")
IO.puts("=" <> String.duplicate("=", 49))

# Final results
final_distance = :math.sqrt(:math.pow(best_params.x - 5.0, 2) + :math.pow(best_params.y - 5.0, 2))
IO.puts("📊 FINAL RESULTS:")
IO.puts("Best Score: #{Float.round(best, 2)}")
IO.puts("Best Position: (#{Float.round(best_params.x, 3)}, #{Float.round(best_params.y, 3)})")
IO.puts("Distance from Target: #{Float.round(final_distance, 3)}")

# Check convergence
first_10 = Enum.take(scores, 10)
last_10 = Enum.take(scores, -10)
first_avg = Enum.sum(first_10) / length(first_10)
last_avg = Enum.sum(last_10) / length(last_10)

IO.puts("")
IO.puts("📈 CONVERGENCE ANALYSIS:")
IO.puts("First 10 trials avg score: #{Float.round(first_avg, 2)}")
IO.puts("Last 10 trials avg score: #{Float.round(last_avg, 2)}")

improvement = if first_avg < 0, do: (last_avg - first_avg) / abs(first_avg) * 100, else: 0
IO.puts("Improvement: #{Float.round(improvement, 1)}%")

IO.puts("")
cond do
  final_distance < 1.0 ->
    IO.puts("✅ TPE CONVERGED! Found optimum within 1.0 units!")
  final_distance < 2.0 ->
    IO.puts("✅ TPE partially converged (within 2.0 units)")
  true ->
    IO.puts("⚠️  TPE needs more tuning or trials")
end

cond do
  improvement > 50 ->
    IO.puts("✅ TPE showed strong learning (>50% improvement)")
  improvement > 20 ->
    IO.puts("✅ TPE showed moderate learning")
  true ->
    IO.puts("⚠️  TPE learning was weak")
end