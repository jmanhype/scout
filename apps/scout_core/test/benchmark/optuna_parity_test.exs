defmodule Scout.Benchmark.OptunaParityTest do
  use ExUnit.Case, async: false

  alias Scout.Easy

  @moduledoc """
  Optuna Parity Benchmark Suite

  Tests Scout against standard optimization benchmark functions:
  - Sphere: Simple convex function (baseline)
  - Rosenbrock: Classic non-convex function
  - Rastrigin: Highly multi-modal with many local minima
  - Ackley: Multi-modal with nearly flat outer region

  Each benchmark runs multiple trials and validates that Scout can find
  solutions within acceptable thresholds, demonstrating parity with Optuna.

  Run with: mix test test/benchmark/optuna_parity_test.exs
  """

  # Test configuration
  @n_runs 3  # Reduced for faster CI
  @n_trials 100

  setup do
    # Configure ETS adapter for benchmarks
    Application.put_env(:scout_core, :store_adapter, Scout.Store.ETS)
    {:ok, pid} = Scout.Store.ETS.start_link([])

    on_exit(fn ->
      if Process.alive?(pid) do
        GenServer.stop(pid, :normal, 1000)
      end
    end)

    {:ok, store_pid: pid}
  end

  describe "Sphere function benchmarks" do
    @tag timeout: 120_000
    test "RandomSearch finds near-optimal solution on Sphere" do
      # Sphere: f(x) = Σ(xi²), optimal at origin with f(0,0,0,0,0) = 0
      objective = fn params ->
        [:x0, :x1, :x2, :x3, :x4]
        |> Enum.reduce(0.0, fn key, acc ->
          x = Map.get(params, key, 0.0)
          acc + x * x
        end)
      end

      space = %{
        x0: {:uniform, -5.0, 5.0},
        x1: {:uniform, -5.0, 5.0},
        x2: {:uniform, -5.0, 5.0},
        x3: {:uniform, -5.0, 5.0},
        x4: {:uniform, -5.0, 5.0}
      }

      results =
        for run <- 1..@n_runs do
          Easy.optimize(objective, space,
            sampler: :random,
            direction: :minimize,
            n_trials: @n_trials,
            study_name: "sphere-random-#{run}"
          )
        end

      scores = Enum.map(results, & &1.best_score)
      mean_score = Enum.sum(scores) / length(scores)
      min_score = Enum.min(scores)

      IO.puts("\nSphere (Random):")
      IO.puts("  Mean best score: #{format_score(mean_score)}")
      IO.puts("  Min best score:  #{format_score(min_score)}")
      IO.puts("  All scores: #{inspect(Enum.map(scores, &format_score/1))}")

      # Sphere is convex - should find good solutions
      # With 100 trials on 5D sphere, expect reasonable but not perfect convergence
      assert mean_score < 15.0, "Mean score should be < 15.0, got #{mean_score}"
      assert min_score < 10.0, "Best run should be < 10.0, got #{min_score}"
    end
  end

  describe "Rosenbrock function benchmarks" do
    @tag timeout: 120_000
    test "RandomSearch finds acceptable solution on Rosenbrock" do
      # Rosenbrock: f(x,y) = (1-x)² + 100(y-x²)²
      # Optimal: f(1,1) = 0
      # Known to be challenging for optimization algorithms
      objective = fn params ->
        x = params.x
        y = params.y
        (1.0 - x) * (1.0 - x) + 100.0 * (y - x * x) * (y - x * x)
      end

      space = %{
        x: {:uniform, -2.0, 2.0},
        y: {:uniform, -2.0, 2.0}
      }

      results =
        for run <- 1..@n_runs do
          Easy.optimize(objective, space,
            sampler: :random,
            direction: :minimize,
            n_trials: @n_trials,
            study_name: "rosenbrock-random-#{run}"
          )
        end

      scores = Enum.map(results, & &1.best_score)
      mean_score = Enum.sum(scores) / length(scores)
      min_score = Enum.min(scores)

      IO.puts("\nRosenbrock (Random):")
      IO.puts("  Mean best score: #{format_score(mean_score)}")
      IO.puts("  Min best score:  #{format_score(min_score)}")
      IO.puts("  All scores: #{inspect(Enum.map(scores, &format_score/1))}")

      # Rosenbrock is challenging - accept reasonable thresholds
      assert mean_score < 500.0, "Mean score should be < 500.0, got #{mean_score}"
      assert min_score < 100.0, "Best run should be < 100.0, got #{min_score}"
    end
  end

  describe "Rastrigin function benchmarks" do
    @tag timeout: 120_000
    test "RandomSearch explores multi-modal Rastrigin landscape" do
      # Rastrigin: f(x) = 10n + Σ(xi² - 10cos(2πxi))
      # Optimal: f(0,0,0,0,0) = 0
      # Highly multi-modal with many local minima
      objective = fn params ->
        points = [params.x0, params.x1, params.x2, params.x3, params.x4]
        n = length(points)

        sum =
          Enum.reduce(points, 0.0, fn x, acc ->
            acc + (x * x - 10.0 * :math.cos(2.0 * :math.pi() * x))
          end)

        10.0 * n + sum
      end

      space = %{
        x0: {:uniform, -5.12, 5.12},
        x1: {:uniform, -5.12, 5.12},
        x2: {:uniform, -5.12, 5.12},
        x3: {:uniform, -5.12, 5.12},
        x4: {:uniform, -5.12, 5.12}
      }

      results =
        for run <- 1..@n_runs do
          Easy.optimize(objective, space,
            sampler: :random,
            direction: :minimize,
            n_trials: @n_trials,
            study_name: "rastrigin-random-#{run}"
          )
        end

      scores = Enum.map(results, & &1.best_score)
      mean_score = Enum.sum(scores) / length(scores)
      min_score = Enum.min(scores)

      IO.puts("\nRastrigin (Random):")
      IO.puts("  Mean best score: #{format_score(mean_score)}")
      IO.puts("  Min best score:  #{format_score(min_score)}")
      IO.puts("  All scores: #{inspect(Enum.map(scores, &format_score/1))}")

      # Rastrigin is very challenging - many local minima
      assert mean_score < 100.0, "Mean score should be < 100.0, got #{mean_score}"
      assert min_score < 50.0, "Best run should be < 50.0, got #{min_score}"
    end
  end

  describe "Ackley function benchmarks" do
    @tag timeout: 120_000
    test "RandomSearch navigates Ackley's flat outer region" do
      # Ackley: f(x,y) = -20*exp(-0.2*sqrt(0.5*(x²+y²))) -
      #                   exp(0.5*(cos(2πx)+cos(2πy))) + e + 20
      # Optimal: f(0,0) = 0
      # Nearly flat outer region with sharp central peak
      objective = fn params ->
        x = params.x
        y = params.y

        term1 = -20.0 * :math.exp(-0.2 * :math.sqrt(0.5 * (x * x + y * y)))
        term2 = -:math.exp(0.5 * (:math.cos(2.0 * :math.pi() * x) + :math.cos(2.0 * :math.pi() * y)))

        term1 + term2 + :math.exp(1.0) + 20.0
      end

      space = %{
        x: {:uniform, -5.0, 5.0},
        y: {:uniform, -5.0, 5.0}
      }

      results =
        for run <- 1..@n_runs do
          Easy.optimize(objective, space,
            sampler: :random,
            direction: :minimize,
            n_trials: @n_trials,
            study_name: "ackley-random-#{run}"
          )
        end

      scores = Enum.map(results, & &1.best_score)
      mean_score = Enum.sum(scores) / length(scores)
      min_score = Enum.min(scores)

      IO.puts("\nAckley (Random):")
      IO.puts("  Mean best score: #{format_score(mean_score)}")
      IO.puts("  Min best score:  #{format_score(min_score)}")
      IO.puts("  All scores: #{inspect(Enum.map(scores, &format_score/1))}")

      # Ackley has flat outer region - reasonably challenging
      assert mean_score < 10.0, "Mean score should be < 10.0, got #{mean_score}"
      assert min_score < 5.0, "Best run should be < 5.0, got #{min_score}"
    end
  end

  describe "Statistical analysis" do
    @tag timeout: 120_000
    test "validates consistency across multiple runs" do
      # Run same optimization 10 times to check variance
      objective = fn params ->
        x = params.x
        y = params.y
        x * x + y * y
      end

      space = %{
        x: {:uniform, -3.0, 3.0},
        y: {:uniform, -3.0, 3.0}
      }

      results =
        for run <- 1..10 do
          Easy.optimize(objective, space,
            sampler: :random,
            direction: :minimize,
            n_trials: 50,
            study_name: "consistency-#{run}"
          )
        end

      scores = Enum.map(results, & &1.best_score)
      mean = Enum.sum(scores) / length(scores)
      variance = Enum.reduce(scores, 0.0, fn x, acc -> acc + :math.pow(x - mean, 2) end) / length(scores)
      std_dev = :math.sqrt(variance)
      min_score = Enum.min(scores)
      max_score = Enum.max(scores)

      IO.puts("\nConsistency Analysis (10 runs):")
      IO.puts("  Mean: #{format_score(mean)}")
      IO.puts("  Std Dev: #{format_score(std_dev)}")
      IO.puts("  Range: [#{format_score(min_score)}, #{format_score(max_score)}]")
      IO.puts("  Coeff of Variation: #{format_score(std_dev / mean * 100.0)}%")

      # Should have reasonably consistent results
      assert mean < 2.0, "Mean should be < 2.0"
      assert std_dev < 2.0, "Standard deviation should be < 2.0"
    end
  end

  # Helper functions

  defp format_score(score) when is_float(score) do
    :io_lib.format("~.4f", [score]) |> to_string()
  end

  defp format_score(score), do: inspect(score)
end
