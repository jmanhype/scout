# Benchmark Utilities for Scout
# Common objective functions and helpers for performance benchmarking

defmodule Benchmark.Util do
  @moduledoc """
  Common utilities for benchmarking Scout optimization performance.

  Provides standard optimization test functions (Rosenbrock, Rastrigin, Sphere, etc.)
  and helper functions for running consistent benchmarks.
  """

  @doc """
  Rosenbrock function (aka banana function).
  Global minimum: f([1, 1, ...]) = 0
  Domain: typically [-5, 10] for each dimension

  Characteristics:
  - Unimodal but has a narrow curved valley
  - Easy to find valley, hard to converge to minimum
  - Classic test for optimization algorithms
  """
  def rosenbrock(params) when is_map(params) do
    params
    |> Map.values()
    |> rosenbrock()
  end

  def rosenbrock(params) when is_list(params) do
    params
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [x, y] ->
      a = 1 - x
      b = y - x * x
      a * a + 100 * b * b
    end)
    |> Enum.sum()
  end

  @doc """
  Rastrigin function.
  Global minimum: f([0, 0, ...]) = 0
  Domain: typically [-5.12, 5.12] for each dimension

  Characteristics:
  - Highly multimodal with many local minima
  - Regular pattern of minima
  - Tests global search capability
  """
  def rastrigin(params) when is_map(params) do
    params |> Map.values() |> rastrigin()
  end

  def rastrigin(params) when is_list(params) do
    n = length(params)
    a = 10

    params
    |> Enum.map(fn x ->
      x * x - a * :math.cos(2 * :math.pi() * x)
    end)
    |> Enum.sum()
    |> Kernel.+(a * n)
  end

  @doc """
  Sphere function.
  Global minimum: f([0, 0, ...]) = 0
  Domain: typically [-5.12, 5.12] for each dimension

  Characteristics:
  - Simplest continuous function
  - Unimodal, convex, differentiable
  - Tests basic convergence
  """
  def sphere(params) when is_map(params) do
    params |> Map.values() |> sphere()
  end

  def sphere(params) when is_list(params) do
    params
    |> Enum.map(fn x -> x * x end)
    |> Enum.sum()
  end

  @doc """
  Ackley function.
  Global minimum: f([0, 0, ...]) = 0
  Domain: typically [-5, 5] for each dimension

  Characteristics:
  - Multimodal with many local minima
  - Nearly flat outer region
  - Tests exploration vs exploitation
  """
  def ackley(params) when is_map(params) do
    params |> Map.values() |> ackley()
  end

  def ackley(params) when is_list(params) do
    n = length(params)

    sum_sq = Enum.sum(Enum.map(params, fn x -> x * x end))
    sum_cos = Enum.sum(Enum.map(params, fn x -> :math.cos(2 * :math.pi() * x) end))

    -20 * :math.exp(-0.2 * :math.sqrt(sum_sq / n)) -
    :math.exp(sum_cos / n) + 20 + :math.exp(1)
  end

  @doc """
  Generate search space for continuous optimization.

  ## Examples
      # 2D optimization in [-5, 5]
      continuous_space(2, -5, 5)

      # 10D optimization in [-10, 10]
      continuous_space(10, -10, 10)
  """
  def continuous_space(dimensions, min, max) do
    1..dimensions
    |> Enum.map(fn i ->
      {String.to_atom("x#{i}"), {:continuous, min, max}}
    end)
    |> Map.new()
  end

  @doc """
  Standard Benchee configuration for Scout benchmarks.

  Returns consistent configuration for:
  - Time measurement (2 seconds warmup, 5 seconds run)
  - Memory measurement enabled
  - Console formatter with extended statistics
  """
  def benchee_config do
    [
      time: 5,
      warmup: 2,
      memory_time: 2,
      formatters: [
        {Benchee.Formatters.Console,
         extended_statistics: true}
      ],
      print: [
        fast_warning: false,
        configuration: true
      ]
    ]
  end

  @doc """
  Run an optimization and return best value found.
  Helper for benchmarking that runs Scout and extracts the result.
  """
  def run_optimization(objective_fn, space, opts \\ []) do
    n_trials = Keyword.get(opts, :n_trials, 50)
    sampler = Keyword.get(opts, :sampler, :random)
    direction = Keyword.get(opts, :direction, :minimize)

    result = Scout.Easy.optimize(
      objective_fn,
      space,
      n_trials: n_trials,
      sampler: sampler,
      direction: direction
    )

    result.best_value
  end

  @doc """
  Environment information for benchmark reports.
  Returns a map with Elixir version, OTP version, and system info.
  """
  def env_info do
    %{
      elixir_version: System.version(),
      otp_version: :erlang.system_info(:otp_release) |> to_string(),
      scout_version: Application.spec(:scout_core, :vsn) |> to_string(),
      schedulers: :erlang.system_info(:schedulers),
      schedulers_online: :erlang.system_info(:schedulers_online)
    }
  end

  @doc """
  Print environment information to console.
  """
  def print_env_info do
    info = env_info()

    IO.puts("\n" <> String.duplicate("=", 60))
    IO.puts("Scout Benchmark Environment")
    IO.puts(String.duplicate("=", 60))
    IO.puts("Elixir version: #{info.elixir_version}")
    IO.puts("OTP version: #{info.otp_version}")
    IO.puts("Scout version: #{info.scout_version}")
    IO.puts("Schedulers: #{info.schedulers} (#{info.schedulers_online} online)")
    IO.puts(String.duplicate("=", 60) <> "\n")
  end
end
