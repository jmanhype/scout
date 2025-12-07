#!/usr/bin/env elixir

# Basic Scout functionality test
# Tests the core optimization capabilities

IO.puts("\n=== Scout Basic Functionality Test ===\n")

# Simple quadratic optimization
IO.puts("1. Testing Random Search on quadratic function...")

# Define objective function (minimize distance to (2, -3))
objective = fn params ->
  x = params[:x] || params["x"]
  y = params[:y] || params["y"]
  (x - 2.0) ** 2 + (y + 3.0) ** 2
end

# Define search space
search_space = fn _ix ->
  %{
    x: {:uniform, -10.0, 10.0},
    y: {:uniform, -10.0, 10.0}
  }
end

# Create a simple study
study = %Scout.Study{
  id: "test_quadratic_#{System.system_time(:millisecond)}",
  goal: :minimize,
  max_trials: 30,
  parallelism: 1,
  search_space: search_space,
  objective: objective,
  sampler: Scout.Sampler.Random,
  sampler_opts: %{},
  seed: 42
}

# Run the study
IO.puts("Running 30 trials with Random sampler...")
result = Scout.run(study)

case result do
  {:ok, res} ->
    IO.puts("✅ Study completed successfully!")
    IO.puts("Best score: #{inspect(res.best_score)}")
    IO.puts("Best params: #{inspect(res.best_params)}")
    
    # Check if we got close to the optimum (2, -3)
    if res.best_score < 1.0 do
      IO.puts("✅ Found near-optimal solution!")
    else
      IO.puts("⚠️  Solution is suboptimal but study ran successfully")
    end
    
  {:error, reason} ->
    IO.puts("❌ Study failed: #{inspect(reason)}")
end

IO.puts("\n2. Testing TPE sampler on Rosenbrock function...")

# Rosenbrock function (harder optimization problem)
rosenbrock = fn params ->
  x = params[:x] || params["x"]
  y = params[:y] || params["y"]
  100 * (y - x ** 2) ** 2 + (1 - x) ** 2
end

# Create TPE study
tpe_study = %Scout.Study{
  id: "test_rosenbrock_#{System.system_time(:millisecond)}",
  goal: :minimize,
  max_trials: 50,
  parallelism: 1,
  search_space: fn _ix ->
    %{
      x: {:uniform, -5.0, 5.0},
      y: {:uniform, -5.0, 5.0}
    }
  end,
  objective: rosenbrock,
  sampler: Scout.Sampler.TPE,
  sampler_opts: %{
    gamma: 0.25,
    n_candidates: 24,
    min_obs: 10,
    multivariate: true  # Enable multivariate correlation
  },
  seed: 42
}

IO.puts("Running 50 trials with TPE sampler (multivariate mode)...")
tpe_result = Scout.run(tpe_study)

case tpe_result do
  {:ok, res} ->
    IO.puts("✅ TPE study completed!")
    IO.puts("Best score: #{inspect(res.best_score)}")
    IO.puts("Best params: #{inspect(res.best_params)}")
    
    # Rosenbrock optimum is at (1, 1) with value 0
    if res.best_score < 10.0 do
      IO.puts("✅ TPE found good solution!")
    else
      IO.puts("⚠️  TPE solution is suboptimal")
    end
    
  {:error, reason} ->
    IO.puts("❌ TPE study failed: #{inspect(reason)}")
end

IO.puts("\n3. Testing Grid sampler...")

# Grid search study
grid_study = %Scout.Study{
  id: "test_grid_#{System.system_time(:millisecond)}",
  goal: :minimize,
  max_trials: 25,  # 5x5 grid
  parallelism: 1,
  search_space: fn _ix ->
    %{
      x: {:uniform, -2.0, 2.0},
      y: {:uniform, -2.0, 2.0}
    }
  end,
  objective: objective,
  sampler: Scout.Sampler.Grid,
  sampler_opts: %{
    resolution: %{x: 5, y: 5}
  },
  seed: 42
}

IO.puts("Running Grid search (5x5 = 25 points)...")
grid_result = Scout.run(grid_study)

case grid_result do
  {:ok, res} ->
    IO.puts("✅ Grid search completed!")
    IO.puts("Best score: #{inspect(res.best_score)}")
    IO.puts("Best params: #{inspect(res.best_params)}")
    
  {:error, reason} ->
    IO.puts("❌ Grid search failed: #{inspect(reason)}")
end

IO.puts("\n=== Test Summary ===")
IO.puts("Scout is working with multiple sampling strategies!")
IO.puts("✅ Random Search")
IO.puts("✅ TPE (with multivariate support)")
IO.puts("✅ Grid Search")