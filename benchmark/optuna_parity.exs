#!/usr/bin/env elixir
#
# Optuna Parity Benchmark Suite
#
# Tests Scout against standard optimization benchmark functions:
# - Rosenbrock: Classic non-convex function
# - Rastrigin: Highly multi-modal with many local minima
# - Ackley: Multi-modal with nearly flat outer region
# - Sphere: Simple convex function (baseline)
#
# Each function is run 10 times to compute statistical metrics:
# - Mean best score
# - Median best score
# - Standard deviation
# - Min/Max best scores
# - Success rate (reaching threshold)
#
# Usage:
#   mix run benchmark/optuna_parity.exs

Mix.install([])

defmodule OptunaParity do
  @moduledoc """
  Benchmark suite for validating Scout's optimization performance
  against standard benchmark functions.
  """

  # Benchmark configuration
  @n_runs 10
  @n_trials 100
  @samplers [:random, :tpe, :grid]

  def run do
    IO.puts("\n" <> IO.ANSI.cyan() <> "=" <> String.duplicate("=", 78) <> IO.ANSI.reset())
    IO.puts(IO.ANSI.cyan() <> "  Scout Optuna Parity Benchmark Suite" <> IO.ANSI.reset())
    IO.puts(IO.ANSI.cyan() <> "=" <> String.duplicate("=", 78) <> IO.ANSI.reset())
    IO.puts("")
    IO.puts("Configuration:")
    IO.puts("  Runs per function:  #{@n_runs}")
    IO.puts("  Trials per run:     #{@n_trials}")
    IO.puts("  Samplers tested:    #{inspect(@samplers)}")
    IO.puts("")

    benchmarks = [
      %{
        name: "Sphere",
        function: &sphere/1,
        search_space: sphere_space(),
        optimal_value: 0.0,
        threshold: 1.0,
        dimensions: 5
      },
      %{
        name: "Rosenbrock",
        function: &rosenbrock/1,
        search_space: rosenbrock_space(),
        optimal_value: 0.0,
        threshold: 100.0,
        dimensions: 2
      },
      %{
        name: "Rastrigin",
        function: &rastrigin/1,
        search_space: rastrigin_space(),
        optimal_value: 0.0,
        threshold: 10.0,
        dimensions: 5
      },
      %{
        name: "Ackley",
        function: &ackley/1,
        search_space: ackley_space(),
        optimal_value: 0.0,
        threshold: 1.0,
        dimensions: 2
      }
    ]

    results =
      for benchmark <- benchmarks do
        run_benchmark(benchmark)
      end

    print_summary(results)
  end

  defp run_benchmark(benchmark) do
    IO.puts(IO.ANSI.yellow() <> "\n▸ #{benchmark.name} Function" <> IO.ANSI.reset())
    IO.puts("  Optimal value: #{benchmark.optimal_value}")
    IO.puts("  Success threshold: < #{benchmark.threshold}")
    IO.puts("  Dimensions: #{benchmark.dimensions}")
    IO.puts("")

    sampler_results =
      for sampler <- @samplers do
        run_sampler_benchmark(benchmark, sampler)
      end

    %{
      name: benchmark.name,
      optimal: benchmark.optimal_value,
      threshold: benchmark.threshold,
      sampler_results: sampler_results
    }
  end

  defp run_sampler_benchmark(benchmark, sampler) do
    IO.write("  #{format_sampler_name(sampler)}: ")

    scores =
      for run <- 1..@n_runs do
        if rem(run, 2) == 0, do: IO.write(".")

        result =
          Scout.Easy.optimize(
            benchmark.function,
            benchmark.search_space,
            sampler: sampler,
            direction: :minimize,
            n_trials: @n_trials,
            study_name: "bench-#{benchmark.name}-#{sampler}-#{run}"
          )

        result.best_score
      end

    IO.write(" ")

    stats = compute_statistics(scores, benchmark.threshold)
    print_stats(stats)

    %{
      sampler: sampler,
      scores: scores,
      stats: stats
    }
  end

  defp compute_statistics(scores, threshold) do
    sorted = Enum.sort(scores)
    n = length(scores)

    mean = Enum.sum(scores) / n
    median = Enum.at(sorted, div(n, 2))

    variance = Enum.reduce(scores, 0.0, fn x, acc -> acc + :math.pow(x - mean, 2) end) / n
    std_dev = :math.sqrt(variance)

    min_score = Enum.min(scores)
    max_score = Enum.max(scores)

    success_count = Enum.count(scores, &(&1 < threshold))
    success_rate = success_count / n * 100.0

    %{
      mean: mean,
      median: median,
      std_dev: std_dev,
      min: min_score,
      max: max_score,
      success_rate: success_rate,
      success_count: success_count,
      total_runs: n
    }
  end

  defp print_stats(stats) do
    IO.puts(
      IO.ANSI.green() <>
        "Mean: #{format_score(stats.mean)} | " <>
        "Median: #{format_score(stats.median)} | " <>
        "Std: #{format_score(stats.std_dev)} | " <>
        "Range: [#{format_score(stats.min)}, #{format_score(stats.max)}] | " <>
        "Success: #{stats.success_count}/#{stats.total_runs} (#{format_percent(stats.success_rate)})" <>
        IO.ANSI.reset()
    )
  end

  defp print_summary(results) do
    IO.puts("\n" <> IO.ANSI.cyan() <> "=" <> String.duplicate("=", 78) <> IO.ANSI.reset())
    IO.puts(IO.ANSI.cyan() <> "  Benchmark Summary" <> IO.ANSI.reset())
    IO.puts(IO.ANSI.cyan() <> "=" <> String.duplicate("=", 78) <> IO.ANSI.reset())

    for result <- results do
      IO.puts("\n#{IO.ANSI.yellow()}#{result.name} (target: < #{result.threshold})#{IO.ANSI.reset()}")

      for sampler_result <- result.sampler_results do
        stats = sampler_result.stats
        sampler_name = format_sampler_name(sampler_result.sampler)

        status =
          if stats.success_rate >= 70.0 do
            IO.ANSI.green() <> "✓ PASS" <> IO.ANSI.reset()
          else
            IO.ANSI.red() <> "✗ FAIL" <> IO.ANSI.reset()
          end

        IO.puts(
          "  #{String.pad_trailing(sampler_name, 12)} → " <>
            "#{format_score(stats.mean)} ± #{format_score(stats.std_dev)} " <>
            "(#{format_percent(stats.success_rate)}) #{status}"
        )
      end
    end

    IO.puts("")
  end

  # ============================================================================
  # Benchmark Functions
  # ============================================================================

  @doc """
  Sphere function: f(x) = Σ(xi²)
  Optimal: f(0,...,0) = 0
  Simple convex function for baseline testing.
  """
  def sphere(params) do
    Enum.reduce([:x0, :x1, :x2, :x3, :x4], 0.0, fn key, acc ->
      x = Map.get(params, key, 0.0)
      acc + x * x
    end)
  end

  def sphere_space do
    %{
      x0: {:uniform, -5.0, 5.0},
      x1: {:uniform, -5.0, 5.0},
      x2: {:uniform, -5.0, 5.0},
      x3: {:uniform, -5.0, 5.0},
      x4: {:uniform, -5.0, 5.0}
    }
  end

  @doc """
  Rosenbrock function: f(x,y) = (1-x)² + 100(y-x²)²
  Optimal: f(1,1) = 0
  Classic non-convex optimization benchmark.
  """
  def rosenbrock(params) do
    x = params.x
    y = params.y
    (1.0 - x) * (1.0 - x) + 100.0 * (y - x * x) * (y - x * x)
  end

  def rosenbrock_space do
    %{
      x: {:uniform, -2.0, 2.0},
      y: {:uniform, -2.0, 2.0}
    }
  end

  @doc """
  Rastrigin function: f(x) = 10n + Σ(xi² - 10cos(2πxi))
  Optimal: f(0,...,0) = 0
  Highly multi-modal with many local minima.
  """
  def rastrigin(params) do
    points = [params.x0, params.x1, params.x2, params.x3, params.x4]
    n = length(points)

    sum =
      Enum.reduce(points, 0.0, fn x, acc ->
        acc + (x * x - 10.0 * :math.cos(2.0 * :math.pi() * x))
      end)

    10.0 * n + sum
  end

  def rastrigin_space do
    %{
      x0: {:uniform, -5.12, 5.12},
      x1: {:uniform, -5.12, 5.12},
      x2: {:uniform, -5.12, 5.12},
      x3: {:uniform, -5.12, 5.12},
      x4: {:uniform, -5.12, 5.12}
    }
  end

  @doc """
  Ackley function:
  f(x,y) = -20*exp(-0.2*sqrt(0.5*(x²+y²))) - exp(0.5*(cos(2πx)+cos(2πy))) + e + 20
  Optimal: f(0,0) = 0
  Multi-modal with nearly flat outer region.
  """
  def ackley(params) do
    x = params.x
    y = params.y

    term1 = -20.0 * :math.exp(-0.2 * :math.sqrt(0.5 * (x * x + y * y)))
    term2 = -:math.exp(0.5 * (:math.cos(2.0 * :math.pi() * x) + :math.cos(2.0 * :math.pi() * y)))

    term1 + term2 + :math.exp(1.0) + 20.0
  end

  def ackley_space do
    %{
      x: {:uniform, -5.0, 5.0},
      y: {:uniform, -5.0, 5.0}
    }
  end

  # ============================================================================
  # Formatting Helpers
  # ============================================================================

  defp format_sampler_name(:random), do: "Random"
  defp format_sampler_name(:tpe), do: "TPE"
  defp format_sampler_name(:grid), do: "Grid"
  defp format_sampler_name(:cmaes), do: "CMA-ES"
  defp format_sampler_name(sampler), do: "#{sampler}"

  defp format_score(score) when is_float(score) do
    :io_lib.format("~.4f", [score]) |> to_string()
  end

  defp format_percent(percent) when is_float(percent) do
    "#{round(percent)}%"
  end
end

# Run the benchmark suite
OptunaParity.run()
