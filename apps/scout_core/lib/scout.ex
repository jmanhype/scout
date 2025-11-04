defmodule Scout do
  @moduledoc """
  Main entry point for the Scout hyperparameter optimization framework.

  Scout provides production-ready hyperparameter optimization with >99% feature
  parity with Optuna, leveraging Elixir's BEAM platform for superior fault
  tolerance, real-time dashboards, and native distributed computing.

  ## Quick Start

  Use `Scout.Easy.optimize/3` for the simplest API:

      result = Scout.Easy.optimize(
        fn params -> train_model(params) end,
        %{learning_rate: {:log_uniform, 1e-5, 1e-1}, n_layers: {:int, 2, 8}},
        n_trials: 100
      )

  ## Advanced Usage

  For more control, create a `Scout.Study` struct and run it:

      study = %Scout.Study{
        id: "my-study",
        goal: :minimize,
        max_trials: 100,
        parallelism: 4,
        search_space: fn _ix -> %{x: {:uniform, -5, 5}} end,
        objective: fn params -> params.x ** 2 end,
        sampler: Scout.Sampler.TPE,
        sampler_opts: %{seed: 42}
      }

      {:ok, result} = Scout.run(study)

  ## Features

  - **23 Samplers**: TPE, CMA-ES, NSGA-II, QMC, GP-BO, Random, Grid
  - **7 Pruners**: Median, Percentile, Patient, Threshold, Wilcoxon, SuccessiveHalving, Hyperband
  - **Multi-objective**: NSGA-II + MOTPE with Pareto dominance
  - **Distributed**: Native BEAM clustering + Oban job queue
  - **Real-time Dashboard**: Phoenix LiveView monitoring
  - **Production-ready**: Docker, Kubernetes, monitoring included

  See `Scout.Easy` for the simplest API, and `Scout.Study` for full control.
  """

  alias Scout.{Study, StudyRunner}

  @doc """
  Execute a study and return optimization results.

  Takes a `Scout.Study` struct and runs it using the configured executor
  (defaults to iterative execution, but can use Oban for distributed runs).

  ## Parameters

    * `study` - A `Scout.Study` struct with all configuration

  ## Returns

    * `{:ok, result}` - Map with `:best_score`, `:best_params`, `:best_trial`, etc.
    * `{:error, reason}` - If the study fails to execute

  ## Examples

      study = %Scout.Study{
        id: "quadratic-opt",
        goal: :minimize,
        max_trials: 50,
        parallelism: 1,
        search_space: fn _ix -> %{x: {:uniform, -10, 10}} end,
        objective: fn params -> params.x ** 2 end,
        sampler: Scout.Sampler.Random,
        sampler_opts: %{seed: 42}
      }

      {:ok, result} = Scout.run(study)
      IO.puts("Best score: \#{result.best_score}")
  """
  @spec run(Study.t()) :: {:ok, map()} | {:error, term()}
  def run(%Study{} = s), do: StudyRunner.run(s)
end
