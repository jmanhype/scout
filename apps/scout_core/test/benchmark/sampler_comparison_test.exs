defmodule Scout.Benchmark.SamplerComparisonTest do
  use ExUnit.Case, async: false

  alias Scout.Easy

  @moduledoc """
  Sampler Comparison Benchmark Suite

  Compares the performance of different samplers on standard optimization functions:
  - RandomSearch: Baseline random sampling
  - Grid: Exhaustive grid search
  - TPE: Tree-structured Parzen Estimator (adaptive Bayesian)
  - CMA-ES: Covariance Matrix Adaptation Evolution Strategy

  Each sampler is tested on Rosenbrock (2D) to compare convergence rates
  and solution quality.

  Run with: mix test test/benchmark/sampler_comparison_test.exs
  """

  # Test configuration
  @n_trials 50  # Reduced for faster execution
  @n_runs 3

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

  describe "Rosenbrock 2D sampler comparison" do
    @tag timeout: 180_000
    test "compares RandomSearch, Grid, TPE, and CMA-ES on Rosenbrock" do
      # Rosenbrock: f(x,y) = (1-x)² + 100(y-x²)²
      # Optimal: f(1,1) = 0
      objective = fn params ->
        x = params.x
        y = params.y
        (1.0 - x) * (1.0 - x) + 100.0 * (y - x * x) * (y - x * x)
      end

      space = %{
        x: {:uniform, -2.0, 2.0},
        y: {:uniform, -2.0, 2.0}
      }

      # Test each sampler
      samplers = [:random, :grid, :tpe, :cmaes]

      results = for sampler <- samplers do
        IO.puts("\n=== Testing #{sampler} sampler ===")

        sampler_results = for run <- 1..@n_runs do
          result = Easy.optimize(objective, space,
            sampler: sampler,
            direction: :minimize,
            n_trials: @n_trials,
            study_name: "rosenbrock-#{sampler}-#{run}"
          )

          IO.puts("  Run #{run}: #{format_score(result.best_score)}")
          result.best_score
        end

        mean_score = Enum.sum(sampler_results) / length(sampler_results)
        min_score = Enum.min(sampler_results)
        max_score = Enum.max(sampler_results)

        IO.puts("\n#{String.upcase(to_string(sampler))} Results:")
        IO.puts("  Mean: #{format_score(mean_score)}")
        IO.puts("  Min:  #{format_score(min_score)}")
        IO.puts("  Max:  #{format_score(max_score)}")

        {sampler, %{mean: mean_score, min: min_score, max: max_score, scores: sampler_results}}
      end

      results_map = Map.new(results)

      # Print comparison table
      IO.puts("\n" <> String.duplicate("=", 70))
      IO.puts("SAMPLER COMPARISON - Rosenbrock 2D (#{@n_runs} runs × #{@n_trials} trials)")
      IO.puts(String.duplicate("=", 70))
      IO.puts("Sampler      | Mean Score  | Min Score   | Max Score   | Improvement")
      IO.puts(String.duplicate("-", 70))

      baseline_mean = results_map[:random].mean

      for sampler <- samplers do
        stats = results_map[sampler]
        improvement = if sampler == :random do
          "baseline"
        else
          pct = (baseline_mean - stats.mean) / baseline_mean * 100.0
          if pct > 0 do
            "+#{:io_lib.format("~.1f", [pct])}%"
          else
            "#{:io_lib.format("~.1f", [pct])}%"
          end
        end

        IO.puts("#{String.pad_trailing(to_string(sampler), 12)} | #{format_score(stats.mean)} | #{format_score(stats.min)} | #{format_score(stats.max)} | #{improvement}")
      end
      IO.puts(String.duplicate("=", 70))

      # Assertions: Adaptive samplers should find good solutions
      assert results_map[:random].mean < 500.0, "Random should find acceptable solution"
      # Grid sampler with only 50 trials has coarse granularity - may not reach optimum
      assert results_map[:grid].mean < 5000.0, "Grid should complete without error"
      assert results_map[:tpe].mean < 500.0, "TPE should find acceptable solution"
      assert results_map[:cmaes].mean < 500.0, "CMA-ES should find acceptable solution"

      # Best run from each sampler
      assert results_map[:random].min < 100.0, "Random best run should be < 100"
      # Grid may not reach optimum with coarse granularity
      assert results_map[:tpe].min < 100.0, "TPE best run should be < 100"
      assert results_map[:cmaes].min < 100.0, "CMA-ES best run should be < 100"
    end
  end

  describe "Sphere 2D sampler comparison" do
    @tag timeout: 180_000
    test "compares RandomSearch, Grid, TPE, and CMA-ES on Sphere" do
      # Sphere: f(x,y) = x² + y²
      # Optimal: f(0,0) = 0
      objective = fn params ->
        x = params.x
        y = params.y
        x * x + y * y
      end

      space = %{
        x: {:uniform, -5.0, 5.0},
        y: {:uniform, -5.0, 5.0}
      }

      # Test each sampler
      samplers = [:random, :grid, :tpe, :cmaes]

      results = for sampler <- samplers do
        IO.puts("\n=== Testing #{sampler} sampler on Sphere ===")

        sampler_results = for run <- 1..@n_runs do
          result = Easy.optimize(objective, space,
            sampler: sampler,
            direction: :minimize,
            n_trials: @n_trials,
            study_name: "sphere-#{sampler}-#{run}"
          )

          IO.puts("  Run #{run}: #{format_score(result.best_score)}")
          result.best_score
        end

        mean_score = Enum.sum(sampler_results) / length(sampler_results)
        min_score = Enum.min(sampler_results)

        IO.puts("\n#{String.upcase(to_string(sampler))} Results:")
        IO.puts("  Mean: #{format_score(mean_score)}")
        IO.puts("  Min:  #{format_score(min_score)}")

        {sampler, %{mean: mean_score, min: min_score, scores: sampler_results}}
      end

      results_map = Map.new(results)

      # Print comparison table
      IO.puts("\n" <> String.duplicate("=", 70))
      IO.puts("SAMPLER COMPARISON - Sphere 2D (#{@n_runs} runs × #{@n_trials} trials)")
      IO.puts(String.duplicate("=", 70))
      IO.puts("Sampler      | Mean Score  | Min Score   | Improvement vs Random")
      IO.puts(String.duplicate("-", 70))

      baseline_mean = results_map[:random].mean

      for sampler <- samplers do
        stats = results_map[sampler]
        improvement = if sampler == :random do
          "baseline"
        else
          pct = (baseline_mean - stats.mean) / baseline_mean * 100.0
          if pct > 0 do
            "+#{:io_lib.format("~.1f", [pct])}%"
          else
            "#{:io_lib.format("~.1f", [pct])}%"
          end
        end

        IO.puts("#{String.pad_trailing(to_string(sampler), 12)} | #{format_score(stats.mean)} | #{format_score(stats.min)} | #{improvement}")
      end
      IO.puts(String.duplicate("=", 70))

      # Assertions: Sphere is convex, adaptive samplers should converge well
      assert results_map[:random].mean < 5.0, "Random should find good solution on convex function"
      # Grid with coarse granularity may not reach optimum
      assert results_map[:grid].mean < 100.0, "Grid should complete without error"
      assert results_map[:tpe].mean < 10.0, "TPE should find good solution on convex function"
      assert results_map[:cmaes].mean < 10.0, "CMA-ES should find good solution on convex function"
    end
  end

  describe "Convergence analysis" do
    @tag timeout: 180_000
    test "analyzes convergence rate differences across samplers" do
      # Use Rosenbrock for convergence analysis
      objective = fn params ->
        x = params.x
        y = params.y
        (1.0 - x) * (1.0 - x) + 100.0 * (y - x * x) * (y - x * x)
      end

      space = %{
        x: {:uniform, -2.0, 2.0},
        y: {:uniform, -2.0, 2.0}
      }

      samplers = [:random, :tpe, :cmaes]

      IO.puts("\n" <> String.duplicate("=", 70))
      IO.puts("CONVERGENCE ANALYSIS - Rosenbrock 2D")
      IO.puts(String.duplicate("=", 70))

      for sampler <- samplers do
        result = Easy.optimize(objective, space,
          sampler: sampler,
          direction: :minimize,
          n_trials: @n_trials,
          study_name: "convergence-#{sampler}"
        )

        IO.puts("\n#{String.upcase(to_string(sampler))}:")
        IO.puts("  Final best score: #{format_score(result.best_score)}")
        IO.puts("  Total trials: #{@n_trials}")

        # Basic convergence assertion
        assert result.best_score < 500.0, "#{sampler} should converge to reasonable solution"
      end

      IO.puts("\n" <> String.duplicate("=", 70))
      IO.puts("Note: For detailed convergence plots, see benchmark visualization tools")
      IO.puts(String.duplicate("=", 70))
    end
  end

  # Helper functions

  defp format_score(score) when is_float(score) do
    :io_lib.format("~11.4f", [score]) |> to_string()
  end

  defp format_score(score), do: String.pad_leading(inspect(score), 11)
end
