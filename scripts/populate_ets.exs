# Simple script to populate ETS store with trial data
# This is a standalone Elixir script, not using Mix.install

# Define the objective function
objective = fn params ->
  x = params.x
  y = params.y
  # Simple quadratic function: minimize (x-2)^2 + (y-3)^2
  result = (x - 2) * (x - 2) + (y - 3) * (y - 3)
  result
end

# Define search space
search_space = %{
  x: {:uniform, -5, 5},
  y: {:uniform, -5, 5}
}

IO.puts("Starting optimization with ETS store...")

# Run optimization 
result = Scout.Easy.optimize(
  objective,
  search_space,
  study_id: "live-dashboard-demo",
  n_trials: 25,
  sampler: :tpe,
  pruner: :median,
  parallelism: 2
)

IO.puts("Optimization completed!")
IO.puts("Best value: #{inspect(result.best_value)}")
IO.puts("Best params: #{inspect(result.best_params)}")
IO.puts("Study name: #{result.study_name}")
IO.puts("Status: #{result.status}")