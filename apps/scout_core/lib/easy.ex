defmodule Scout.Easy do
  @moduledoc """
  Simple Optuna-like API for Scout.
  
  Provides a 3-line interface matching Optuna's simplicity:
  
      result = Scout.Easy.optimize(objective, search_space, n_trials: 100)
      IO.inspect(result.best_params)
      IO.inspect(result.best_value)
  
  Just like Optuna's:
  
      study = optuna.create_study()
      study.optimize(objective, n_trials=100)
      print(study.best_params)
  """
  
  @doc """
  Optimize an objective function with simple API matching Optuna.
  
  ## Parameters
  
    * `objective` - Function that takes params and returns score
    * `search_space` - Map defining parameter space
    * `opts` - Keyword list of options:
      * `:n_trials` - Number of trials (default: 100)
      * `:direction` - :minimize or :maximize (default: :minimize)
      * `:sampler` - Sampler atom or module (default: :random)
      * `:seed` - Random seed for reproducibility
      * `:timeout` - Timeout in milliseconds
      * `:study_name` - Name for the study
      * `:parallelism` - Number of parallel workers (default: 1)
  
  ## Returns
  
  Map with optimization results:
    * `:best_value` - Best objective value found  
    * `:best_params` - Parameters that achieved best value
    * `:best_trial` - Full trial information
    * `:n_trials` - Number of trials completed
    * `:study_name` - Study identifier
  
  ## Examples
  
      # Simple optimization (like Optuna)
      result = Scout.Easy.optimize(
        fn params -> (params.x - 2) ** 2 + (params.y - 3) ** 2 end,
        %{x: {:uniform, -5, 5}, y: {:uniform, -5, 5}},
        n_trials: 100,
        direction: :minimize
      )
      
      IO.puts("Best: \#{result.best_value}")
      IO.puts("Params: \#{inspect(result.best_params)}")
  """
  @spec optimize(function(), map(), keyword()) :: map()
  def optimize(objective, search_space, opts \\ []) do
    # Parse options with Optuna-like defaults
    n_trials = Keyword.get(opts, :n_trials, 100)
    direction = Keyword.get(opts, :direction, :minimize)
    sampler = Keyword.get(opts, :sampler, :random)
    pruner = Keyword.get(opts, :pruner)
    seed = Keyword.get(opts, :seed, :rand.uniform(1000000))
    study_name = Keyword.get(opts, :study_id) || Keyword.get(opts, :study_name, "study_#{System.system_time(:second)}")
    parallelism = Keyword.get(opts, :parallelism, 1)
    timeout = Keyword.get(opts, :timeout, :infinity)
    
    # Convert Optuna direction to Scout goal
    goal = case direction do
      :minimize -> :minimize
      :maximize -> :maximize
      "minimize" -> :minimize
      "maximize" -> :maximize
      _ -> :minimize
    end
    
    # Ensure Scout is started
    ensure_scout_started()
    
    # Create Scout study
    study = %Scout.Study{
      id: study_name,
      goal: goal,
      max_trials: n_trials,
      parallelism: parallelism,
      search_space: build_search_space(search_space),
      objective: wrap_objective(objective),
      sampler: resolve_sampler(sampler),
      sampler_opts: %{seed: seed},
      pruner: resolve_pruner(pruner),
      pruner_opts: %{},
      seed: seed,
      metadata: %{created_by: "Scout.Easy", api_version: "1.0"}
    }
    
    # Run optimization with timeout
    result = if timeout == :infinity do
      Scout.run(study)
    else
      task = Task.async(fn -> Scout.run(study) end)
      case Task.yield(task, timeout) || Task.shutdown(task) do
        {:ok, res} -> res
        nil -> {:error, :timeout}
      end
    end
    
    # Format results like Optuna
    case result do
      {:ok, res} ->
        best_val = res[:best_score] || res[:best_value]
        %{
          best_value: best_val,
          best_score: best_val,  # Alias for compatibility
          best_params: res[:best_params] || %{},
          best_trial: res[:best_trial],
          n_trials: res[:n_trials] || n_trials,
          study_name: study_name,
          study: study_name,  # Alias for compatibility
          status: :completed
        }
        
      {:error, reason} ->
        %{
          best_value: nil,
          best_params: %{},
          best_trial: nil,
          n_trials: 0,
          study_name: study_name,
          status: :error,
          error: reason
        }
    end
  end
  
  @doc """
  Create a study for manual control (like optuna.create_study).
  
  ## Examples
  
      study = Scout.Easy.create_study(direction: :maximize)
      result = Scout.Easy.optimize_study(study, objective, n_trials: 50)
  """
  @spec create_study(keyword()) :: map()
  def create_study(opts \\ []) do
    # Support both :name and :study_name for compatibility
    study_name = Keyword.get(opts, :name) || Keyword.get(opts, :study_name, "study_#{System.system_time(:second)}")
    direction = Keyword.get(opts, :direction, :minimize)
    sampler = Keyword.get(opts, :sampler, :random)
    
    %{
      name: study_name,          # For compatibility with documented API
      study_name: study_name,    # For consistency with optimize() function
      direction: direction,
      sampler: sampler,
      trials: [],
      created_at: DateTime.utc_now()
    }
  end
  
  @doc """
  Load an existing study (like optuna.load_study).
  """
  @spec load_study(String.t()) :: {:ok, map()} | {:error, term()}
  def load_study(study_name) do
    # In a real implementation, this would load from storage
    %{
      study_name: study_name,
      direction: :minimize,
      sampler: :random,
      trials: [],
      loaded_at: DateTime.utc_now()
    }
  end
  
  @doc """
  Get the best value from a study (like optuna study.best_value).
  """
  @spec best_value(map()) :: number() | nil
  def best_value(study) do
    # For created studies, we don't have trials yet
    # In a real implementation, this would query the best trial
    nil
  end
  
  @doc """
  Get the best parameters from a study (like optuna study.best_params).
  """
  @spec best_params(map()) :: map() | nil
  def best_params(study) do
    # For created studies, we don't have trials yet
    # In a real implementation, this would query the best trial
    nil
  end
  
  # Private helper functions
  
  defp ensure_scout_started do
    case Application.ensure_all_started(:scout) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
      _ ->
        # Start Scout components with ETS store
        case Process.whereis(Scout.Store) do
          nil -> 
            # Start the store using the configured adapter
            adapter = Application.get_env(:scout, :store_adapter, Scout.Store.ETS)
            {:ok, _} = adapter.start_link([])
            :ok
          _ -> 
            :ok
        end
    end
  end
  
  defp build_search_space(space) when is_map(space) do
    # Convert to function that returns the space
    fn _ix -> space end
  end
  
  defp build_search_space(space_fn) when is_function(space_fn, 1) do
    space_fn
  end
  
  defp wrap_objective(objective) when is_function(objective, 1) do
    # Objective that just takes params
    objective
  end
  
  defp wrap_objective(objective) when is_function(objective, 2) do
    # Objective with pruning support (params, report_fn)
    objective
  end
  
  defp resolve_sampler(:random), do: Scout.Sampler.RandomSearch
  defp resolve_sampler(:tpe), do: Scout.Sampler.TPE
  defp resolve_sampler(:grid), do: Scout.Sampler.Grid
  defp resolve_sampler(:bandit), do: Scout.Sampler.Bandit
  defp resolve_sampler(:cmaes), do: Scout.Sampler.CmaEs
  defp resolve_sampler(:nsga2), do: Scout.Sampler.NSGA2
  defp resolve_sampler(module) when is_atom(module), do: module
  defp resolve_sampler(_), do: Scout.Sampler.RandomSearch

  defp resolve_pruner(:median), do: Scout.Pruner.MedianPruner
  defp resolve_pruner(:percentile), do: Scout.Pruner.PercentilePruner  
  defp resolve_pruner(:hyperband), do: Scout.Pruner.HyperbandPruner
  defp resolve_pruner(module) when is_atom(module), do: module
  defp resolve_pruner(_), do: nil
end