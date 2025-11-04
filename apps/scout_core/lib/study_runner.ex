defmodule Scout.StudyRunner do
  @moduledoc """
  Study execution orchestrator that delegates to the appropriate executor.

  By default uses Iterative executor, but respects the study's executor field
  if specified. This provides a unified entry point for study execution
  regardless of the execution strategy (iterative, Oban, etc.).

  ## Executors

  - `Scout.Executor.Iterative` - Sequential trial execution (default)
  - `Scout.Executor.Local` - Local parallel execution
  - `Scout.Executor.Oban` - Distributed execution via Oban job queue

  ## Examples

      # Use default iterative executor
      study = %Scout.Study{
        id: "my-study",
        goal: :minimize,
        max_trials: 50,
        parallelism: 1,
        search_space: fn _ix -> %{x: {:uniform, -5, 5}} end,
        objective: fn params -> params.x ** 2 end,
        sampler: Scout.Sampler.Random
      }
      {:ok, result} = Scout.StudyRunner.run(study)

      # Use Oban for distributed execution
      study = %Scout.Study{
        id: "distributed-study",
        goal: :minimize,
        max_trials: 100,
        parallelism: 10,
        search_space: fn _ix -> %{x: {:uniform, -5, 5}} end,
        objective: fn params -> params.x ** 2 end,
        sampler: Scout.Sampler.TPE,
        executor: Scout.Executor.Oban
      }
      {:ok, result} = Scout.StudyRunner.run(study)
  """

  alias Scout.{Study, Executor.Iterative}

  @doc """
  Runs a study using the configured executor.

  If the study has an executor field set, that executor will be used.
  Otherwise defaults to Scout.Executor.Iterative.

  ## Parameters

    * `study` - A `Scout.Study` struct with all configuration

  ## Returns

    * `{:ok, result}` - Map with optimization results
    * `{:error, reason}` - If execution fails

  ## Examples

      study = %Scout.Study{
        id: "example",
        goal: :minimize,
        max_trials: 10,
        parallelism: 1,
        search_space: fn _ix -> %{x: {:uniform, -5, 5}} end,
        objective: fn params -> params.x ** 2 end,
        sampler: Scout.Sampler.Random,
        sampler_opts: %{seed: 42}
      }
      {:ok, result} = Scout.StudyRunner.run(study)
  """
  @spec run(Study.t()) :: {:ok, map()} | {:error, term()}
  def run(%Study{executor: exec_mod} = study) when is_atom(exec_mod) and not is_nil(exec_mod) do
    exec_mod.run(study)
  end

  @spec run(Study.t()) :: {:ok, map()} | {:error, term()}
  def run(%Study{} = study) do
    Iterative.run(study)
  end
end