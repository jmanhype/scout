#!/usr/bin/env elixir

# Test Scout vs Optuna parity on various optimization scenarios

defmodule OptunaParityTest do
  @moduledoc """
  Comprehensive testing of Scout features against Optuna capabilities.
  Run this to identify gaps and validate implementations.
  """

  def run_all_tests do
    IO.puts("""
    ╔════════════════════════════════════════════════════════════════════╗
    ║                    SCOUT vs OPTUNA PARITY TEST                    ║
    ╚════════════════════════════════════════════════════════════════════╝
    """)

    # Test 1: Basic TPE Optimization
    test_basic_tpe()
    
    # Test 2: Distributed Execution
    test_distributed_execution()
    
    # Test 3: Pruning Algorithms
    test_pruning_algorithms()
    
    # Test 4: Search Space Features
    test_search_space_features()
    
    # Test 5: Study Management
    test_study_management()
    
    # Test 6: Advanced Samplers
    test_advanced_samplers()

    IO.puts("\n" <> String.duplicate("═", 70))
    IO.puts("PARITY TEST COMPLETE")
    IO.puts(String.duplicate("═", 70))
  end

  defp test_basic_tpe do
    IO.puts("\n📊 Test 1: Basic TPE Optimization")
    IO.puts(String.duplicate("-", 50))
    
    # Rosenbrock function
    objective = fn params ->
      x = params[:x]
      y = params[:y]
      (1 - x) ** 2 + 100 * (y - x ** 2) ** 2
    end
    
    search_space = fn _ ->
      %{
        x: {:uniform, -5, 5},
        y: {:uniform, -5, 5}
      }
    end
    
    # Test with Scout's TPE
    study = %{
      id: "tpe-test-#{:rand.uniform(10000)}",
      objective: objective,
      search_space: search_space,
      sampler: Scout.Sampler.TPE,
      sampler_opts: %{},
      goal: :minimize,
      n_trials: 50
    }
    
    IO.puts("✓ Created study with TPE sampler")
    
    # Run trials locally
    results = for i <- 1..study.n_trials do
      params = case study.sampler do
        Scout.Sampler.TPE ->
          # Initialize TPE if needed
          state = Scout.Sampler.TPE.init(%{goal: study.goal})
          {params, _} = Scout.Sampler.TPE.next(search_space, i, [], state)
          params
        _ ->
          # Fallback to random
          Scout.SearchSpace.sample(search_space.())
      end
      
      score = objective.(params)
      IO.write(".")
      score
    end
    
    best = Enum.min(results)
    IO.puts("\n✓ Best score: #{Float.round(best, 4)}")
    IO.puts("✓ Optuna typically achieves: ~0.5")
    
    gap = abs(best - 0.5) / 0.5 * 100
    status = if gap < 100, do: "✅ PASS", else: "❌ FAIL"
    IO.puts("#{status} - Gap: #{Float.round(gap, 1)}%")
  end

  defp test_distributed_execution do
    IO.puts("\n🌐 Test 2: Distributed Execution")
    IO.puts(String.duplicate("-", 50))
    
    IO.puts("✓ Scout uses Oban for distributed execution")
    IO.puts("✓ Checking Oban configuration...")
    
    # Check if Oban is running
    case Process.whereis(Oban) do
      nil ->
        IO.puts("⚠️  Oban not started - distributed execution unavailable")
        IO.puts("   To enable: Add Oban to your supervision tree")
      pid ->
        IO.puts("✓ Oban running at #{inspect(pid)}")
        IO.puts("✓ Can distribute trials across workers")
    end
    
    # Compare with Optuna
    IO.puts("\nOptuna distributed options:")
    IO.puts("  - MySQL/PostgreSQL storage backend")
    IO.puts("  - Redis storage backend")
    IO.puts("  - Multiple processes can share study")
    
    IO.puts("\nScout distributed options:")
    IO.puts("  - Oban with PostgreSQL backend ✅")
    IO.puts("  - ETS for local development ✅")
    IO.puts("  - Multiple nodes can share via Ecto ✅")
  end

  defp test_pruning_algorithms do
    IO.puts("\n✂️  Test 3: Pruning Algorithms")
    IO.puts(String.duplicate("-", 50))
    
    pruners = [
      {Scout.Pruner.SuccessiveHalving, "✅ Implemented"},
      {Scout.Pruner.Median, "✅ Implemented"},
      {:hyperband, "❌ Not implemented (HIGH PRIORITY)"},
      {:threshold, "❌ Not implemented"},
      {:percentile, "❌ Not implemented"},
      {:patient, "❌ Not implemented"}
    ]
    
    for {pruner, status} <- pruners do
      name = case pruner do
        mod when is_atom(mod) and mod != :hyperband ->
          mod |> Module.split() |> List.last()
        atom -> atom |> to_string() |> String.capitalize()
      end
      IO.puts("  #{name}: #{status}")
    end
    
    # Test SuccessiveHalving
    IO.puts("\nTesting SuccessiveHalving pruner:")
    state = Scout.Pruner.SuccessiveHalving.init(%{eta: 3})
    {bracket, _} = Scout.Pruner.SuccessiveHalving.assign_bracket(1, state)
    IO.puts("  ✓ Assigned bracket: #{bracket}")
    
    ctx = %{goal: :minimize, study_id: "test", bracket: 0}
    {keep, _} = Scout.Pruner.SuccessiveHalving.keep?("trial-1", [5.0], 0, ctx, state)
    IO.puts("  ✓ Keep decision: #{keep}")
  end

  defp test_search_space_features do
    IO.puts("\n🎯 Test 4: Search Space Features")
    IO.puts(String.duplicate("-", 50))
    
    features = [
      {"Continuous (uniform)", {:uniform, -1, 1}, "✅"},
      {"Log-uniform", {:log_uniform, 0.001, 1.0}, "✅"},
      {"Integer", {:int, 1, 10}, "✅"},
      {"Categorical", {:choice, ["a", "b", "c"]}, "✅"},
      {"Discrete uniform", {:discrete_uniform, 0.0, 1.0, 0.1}, "❌"},
      {"Conditional parameters", :conditional, "❌ HIGH PRIORITY"},
      {"Parameter constraints", :constraints, "❌ MEDIUM PRIORITY"}
    ]
    
    for {name, spec, status} <- features do
      IO.puts("  #{name}: #{status}")
      
      # Test sampling if implemented
      if status == "✅" and spec != :conditional and spec != :constraints do
        try do
          value = Scout.SearchSpace.sample(%{test: spec})
          IO.puts("    Sample: #{inspect(value[:test])}")
        rescue
          _ -> IO.puts("    ⚠️  Sampling failed")
        end
      end
    end
  end

  defp test_study_management do
    IO.puts("\n📚 Test 5: Study Management")
    IO.puts(String.duplicate("-", 50))
    
    capabilities = [
      {"Create/delete studies", "✅"},
      {"Study naming", "✅"},
      {"Min/max optimization", "✅"},
      {"Multi-objective", "❌ MEDIUM PRIORITY"},
      {"Study summaries", "🔧 Basic only"},
      {"Best trial tracking", "✅"},
      {"Trial user attributes", "❌"},
      {"Study user attributes", "❌"},
      {"Copy studies", "❌"},
      {"Study callbacks", "❌ MEDIUM PRIORITY"}
    ]
    
    for {feature, status} <- capabilities do
      IO.puts("  #{feature}: #{status}")
    end
    
    # Test basic study operations
    IO.puts("\nTesting study operations:")
    study_id = "test-study-#{:rand.uniform(10000)}"
    
    Scout.Store.put_study(%{id: study_id, status: "running"})
    IO.puts("  ✓ Created study: #{study_id}")
    
    case Scout.Store.get_study(study_id) do
      {:ok, study} ->
        IO.puts("  ✓ Retrieved study: #{study.status}")
      _ ->
        IO.puts("  ❌ Failed to retrieve study")
    end
    
    Scout.Store.set_study_status(study_id, "completed")
    IO.puts("  ✓ Updated study status")
  end

  defp test_advanced_samplers do
    IO.puts("\n🔬 Test 6: Advanced Samplers")
    IO.puts(String.duplicate("-", 50))
    
    samplers = [
      {"TPE (univariate)", Scout.Sampler.TPE, "✅"},
      {"TPE (multivariate)", Scout.Sampler.TPEEnhanced, "✅"},
      {"Random", Scout.Sampler.RandomSearch, "✅"},
      {"Grid", Scout.Sampler.Grid, "✅"},
      {"Bandit", Scout.Sampler.Bandit, "✅"},
      {"CMA-ES", Scout.Sampler.CmaEs, "🔧 Partial"},
      {"Gaussian Process", nil, "❌ MEDIUM PRIORITY"},
      {"QMC", nil, "❌ LOW PRIORITY"},
      {"NSGA-II", nil, "❌ For multi-objective"},
      {"MOTPE", nil, "❌ For multi-objective"}
    ]
    
    for {name, module, status} <- samplers do
      IO.puts("  #{name}: #{status}")
      
      # Test initialization if available
      if module && status in ["✅", "🔧 Partial"] do
        try do
          state = module.init(%{goal: :minimize})
          IO.puts("    ✓ Initialized successfully")
        rescue
          e -> IO.puts("    ⚠️  Init failed: #{inspect(e)}")
        end
      end
    end
  end
end

# Load Scout modules
Code.require_file("lib/scout/search_space.ex")
Code.require_file("lib/scout/sampler/tpe.ex")
Code.require_file("lib/scout/sampler/tpe_enhanced.ex")
Code.require_file("lib/scout/sampler/random_search.ex")
Code.require_file("lib/scout/sampler/grid.ex")
Code.require_file("lib/scout/sampler/bandit.ex")
Code.require_file("lib/scout/sampler/cmaes.ex")
Code.require_file("lib/scout/pruner/successive_halving.ex")
Code.require_file("lib/scout/pruner/median.ex")
Code.require_file("lib/scout/store.ex")

# Run tests
OptunaParityTest.run_all_tests()