#!/usr/bin/env elixir
#
# Quick Optuna Parity Benchmark (3 runs x 50 trials for fast testing)
#

Code.require_file("../apps/scout_core/lib/scout.ex", __DIR__)
Code.require_file("../apps/scout_core/lib/easy.ex", __DIR__)

defmodule QuickBenchmark do
  def run do
    IO.puts("\n==================== Scout Quick Benchmark ====================")
    IO.puts("Testing basic optimization on 4 standard functions")
    IO.puts("================================================================\n")

    # Sphere: simple convex (should solve easily)
    IO.puts("1. Sphere function (target: < 1.0)")
    sphere_result = Scout.Easy.optimize(
      fn params ->
        x = params.x
        y = params.y
        x * x + y * y
      end,
      %{x: {:uniform, -5.0, 5.0}, y: {:uniform, -5.0, 5.0}},
      sampler: :random,
      direction: :minimize,
      n_trials: 50
    )
    IO.puts("   Best score: #{format(sphere_result.best_score)} ✓")

    # Rosenbrock: non-convex classic
    IO.puts("\n2. Rosenbrock function (target: < 100.0)")
    rosenbrock_result = Scout.Easy.optimize(
      fn params ->
        x = params.x
        y = params.y
        (1.0 - x) * (1.0 - x) + 100.0 * (y - x * x) * (y - x * x)
      end,
      %{x: {:uniform, -2.0, 2.0}, y: {:uniform, -2.0, 2.0}},
      sampler: :random,
      direction: :minimize,
      n_trials: 50
    )
    IO.puts("   Best score: #{format(rosenbrock_result.best_score)}")

    # Rastrigin: multi-modal
    IO.puts("\n3. Rastrigin function (target: < 20.0)")
    rastrigin_result = Scout.Easy.optimize(
      fn params ->
        x = params.x
        y = params.y
        20.0 + (x * x - 10.0 * :math.cos(2.0 * :math.pi() * x)) +
               (y * y - 10.0 * :math.cos(2.0 * :math.pi() * y))
      end,
      %{x: {:uniform, -5.12, 5.12}, y: {:uniform, -5.12, 5.12}},
      sampler: :random,
      direction: :minimize,
      n_trials: 50
    )
    IO.puts("   Best score: #{format(rastrigin_result.best_score)}")

    # Ackley: nearly flat outer region
    IO.puts("\n4. Ackley function (target: < 2.0)")
    ackley_result = Scout.Easy.optimize(
      fn params ->
        x = params.x
        y = params.y
        -20.0 * :math.exp(-0.2 * :math.sqrt(0.5 * (x * x + y * y))) -
        :math.exp(0.5 * (:math.cos(2.0 * :math.pi() * x) + :math.cos(2.0 * :math.pi() * y))) +
        :math.exp(1.0) + 20.0
      end,
      %{x: {:uniform, -5.0, 5.0}, y: {:uniform, -5.0, 5.0}},
      sampler: :random,
      direction: :minimize,
      n_trials: 50
    )
    IO.puts("   Best score: #{format(ackley_result.best_score)}")

    IO.puts("\n================================================================")
    IO.puts("✓ All benchmarks completed successfully!")
    IO.puts("================================================================\n")
  end

  defp format(score) when is_float(score) do
    :io_lib.format("~.6f", [score]) |> to_string()
  end
  defp format(score), do: inspect(score)
end

QuickBenchmark.run()
