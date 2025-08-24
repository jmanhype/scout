# Simple TPE test - direct module test
Code.require_file("lib/scout/study.ex")
Code.require_file("lib/scout/trial.ex")
Code.require_file("lib/scout/search_space.ex")
Code.require_file("lib/scout/sampler/random_search.ex")
Code.require_file("lib/scout/sampler/tpe.ex")

defmodule TPETest do
  def search_space(_index) do
    %{
      x: {:uniform, -10.0, 10.0},
      y: {:uniform, -10.0, 10.0}
    }
  end
  
  def objective(params) do
    # Simple quadratic - optimum at (0, 0)
    score = -(params.x * params.x + params.y * params.y)
    {:ok, score}
  end
end

IO.puts("🧪 TESTING TPE SAMPLER DIRECTLY")
IO.puts("")

# Initialize TPE
state = Scout.Sampler.TPE.init(%{
  min_obs: 5,
  gamma: 0.25,
  n_candidates: 20,
  goal: :maximize
})

history = []
best = -999999
best_params = nil

for i <- 1..20 do
  # Get suggestion from TPE
  {params, state} = Scout.Sampler.TPE.next(&TPETest.search_space/1, i, history, state)
  
  # Evaluate
  {:ok, score} = TPETest.objective(params)
  
  # Update history
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
    IO.puts("Trial #{String.pad_leading(to_string(i), 2)}: NEW BEST! Score: #{Float.round(score, 3)} at (#{Float.round(params.x, 2)}, #{Float.round(params.y, 2)})")
  end
end

IO.puts("")
IO.puts("Best found: #{Float.round(best, 3)} at (#{Float.round(best_params.x, 3)}, #{Float.round(best_params.y, 3)})")
IO.puts("Optimal is: 0.0 at (0.0, 0.0)")

distance = :math.sqrt(best_params.x * best_params.x + best_params.y * best_params.y)
IO.puts("Distance from optimum: #{Float.round(distance, 3)}")

if distance < 2.0 do
  IO.puts("✅ TPE CONVERGED CLOSE TO OPTIMUM!")
else
  IO.puts("⚠️  TPE needs more trials or tuning")
end