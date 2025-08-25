
defmodule Scout.Executor.Oban do
  @moduledoc """
  Durable distributed executor powered by Oban.
  Requirements:
    * You must configure Postgres and Oban in config (see config.sample.exs).
    * For full durability across restarts, define a **Study module**. The Oban worker
      loads objective/search_space from that module (callbacks), not from closures.
  """
  
  @behaviour Scout.Executor
  
  alias Scout.{Store, Telemetry}

  @impl Scout.Executor
  def run(%{id: id} = study) do
    :ok = Store.put_study(study)
    Telemetry.study_created(id, study.goal, %{executor: :oban})
    for ix <- 0..(study.max_trials - 1) do
      args = %{
        "study_id" => id,
        "ix" => ix,
        "module" => to_string(study[:module] || ""),
        "goal" => to_string(study.goal),
        "seed" => study.seed || :erlang.unique_integer([:positive]),
        "sampler" => to_string(study.sampler || Scout.Sampler.RandomSearch),
        "sampler_opts" => study.sampler_opts || %{},
        "pruner" => study.pruner && to_string(study.pruner) || "",
        "pruner_opts" => study.pruner_opts || %{},
        "parallelism" => study.parallelism
      }
      Oban.insert!(Scout.Executor.Oban.TrialWorker.new(args, queue: :scout_trials))
    end
    {:ok, %{best_params: %{}, best_score: :nan}}
  end
end

defmodule Scout.Executor.Oban.TrialWorker do
  use Oban.Worker, queue: :scout_trials, max_attempts: 3
  alias Scout.{Store, Telemetry, Util.Seed}

  @impl true
  def perform(%Oban.Job{args: args}) do
    study_id = args["study_id"]
    ix = args["ix"]
    base_seed = args["seed"]
    :rand.seed(Seed.seed_for(study_id, ix, base_seed))

    # Resolve study module (durable) or fallback to stored meta (non-durable closures)
    {search_space_fun, objective_fun} =
      case resolve_study_callbacks(args["module"]) do
        {:ok, {s_fun, o_fun}} -> {s_fun, o_fun}
        _ -> resolve_from_meta!(study_id)
      end

    # Resolve sampler & pruner modules from string
    sampler_mod = resolve_module(args["sampler"], Scout.Sampler.RandomSearch)
    sampler_state = sampler_mod.init(args["sampler_opts"] || %{})
    pruner_mod = if args["pruner"] in ["", nil], do: nil, else: resolve_module(args["pruner"], nil)
    pruner_state = if pruner_mod, do: pruner_mod.init(args["pruner_opts"] || %{}), else: nil

    history = Store.list_trials(study_id)
    {params, _} = sampler_mod.next(search_space_fun, ix, history, sampler_state)

    # Purpose: Use Store.start_trial/3 instead of crafting %Trial{} directly
    {:ok, id} = Store.start_trial(study_id, params, 0)
    Telemetry.trial_started(study_id, id, ix, params)

    goal = safe_goal_atom(args["goal"] || "maximize")

    result =
      case :erlang.fun_info(objective_fun)[:arity] do
        2 -> run_iterative(objective_fun, pruner_mod, pruner_state, study_id, id, params, goal)
        _ -> run_oneshot(objective_fun, params)
      end

    case result do
      {:ok, score, metrics} ->
        # Purpose: Use Store.finish_trial/4 facade method
        case Store.finish_trial(study_id, id, score, metrics) do
          :ok -> 
            Telemetry.trial_completed(study_id, id, score, 0, :completed)
          {:error, reason} ->
            Telemetry.trial_completed(study_id, id, 0.0, 0, :failed, %{error: "store_update_failed: #{inspect(reason)}"})
        end
      {:error, reason} ->
        # Purpose: Use Store.fail_trial/3 facade method
        case Store.fail_trial(study_id, id, inspect(reason)) do
          :ok -> :ok
          {:error, store_error} ->
            Telemetry.error_occurred(:oban_executor, :store_error, "store_update_failed: #{inspect(store_error)}", %{study_id: study_id, trial_id: id})
        end
        Telemetry.trial_completed(study_id, id, 0.0, 0, :failed, %{error: inspect(reason)})
    end

    :ok
  end

  defp run_oneshot(fun, params) do
    try do
      case fun.(params) do
        {:ok, s, m} -> {:ok, s, m}
        s when is_number(s) -> {:ok, s, %{}}
        other -> {:error, {:invalid_objective_return, other}}
      end
    rescue e -> {:error, e} catch :exit, r -> {:error, {:exit, r}} end
  end

  defp run_iterative(fun, pruner_mod, pruner_state, study_id, trial_id, params, goal) do
    report = fn score, rung ->
      _ = Store.record_observation(study_id, trial_id, 0, rung, score)
      if pruner_mod do
        {keep, _} = pruner_mod.keep?(trial_id, [score], rung, %{goal: goal, study_id: study_id}, pruner_state)
        if keep, do: :continue, else: (Scout.Telemetry.trial_pruned(study_id, trial_id, rung, score, 0, "below_percentile"); :prune)
      else
        :continue
      end
    end
    try do
      case fun.(params, report) do
        {:ok, s, m} -> {:ok, s, m}
        s when is_number(s) -> {:ok, s, %{}}
        other -> {:error, {:invalid_objective_return, other}}
      end
    rescue e -> {:error, e} catch :exit, r -> {:error, {:exit, r}} end
  end

  defp resolve_study_callbacks(""), do: :error
  defp resolve_study_callbacks(nil), do: :error
  defp resolve_study_callbacks(mod_str) do
    # SECURITY FIX: Only allow whitelisted study modules - never create new atoms
    case safe_module_atom(mod_str) do
      {:ok, mod} ->
        if function_exported?(mod, :search_space, 1) and 
           (function_exported?(mod, :objective, 1) or function_exported?(mod, :objective, 2)) do
          {:ok, {&mod.search_space/1, &mod.objective/1}}
        else
          :error
        end
      :error ->
        :error
    end
  end

  defp resolve_from_meta!(study_id) do
    case Store.get_study(study_id) do
      {:ok, %{search_space: s_fun, objective: o_fun}} when is_function(s_fun) and is_function(o_fun) -> {s_fun, o_fun}
      _ -> raise "Study meta lacks durable callbacks. Provide :module in study or Store.put_study/1 with functions."
    end
  end

  defp resolve_module(str, default) do
    case str do
      "" -> default
      nil -> default
      _ -> 
        # SECURITY FIX: Only resolve to existing atoms - never create new ones
        case safe_sampler_atom(str) do
          {:ok, atom} -> atom
          :error -> default
        end
    end
  end
  
  # Security: Whitelist valid goal atoms to prevent atom table exhaustion
  defp safe_goal_atom("maximize"), do: :maximize
  defp safe_goal_atom("minimize"), do: :minimize
  defp safe_goal_atom("MAXIMIZE"), do: :maximize
  defp safe_goal_atom("MINIMIZE"), do: :minimize
  defp safe_goal_atom(unknown) do
    raise ArgumentError, "Invalid goal '#{unknown}'. Use 'maximize' or 'minimize'"
  end

  # Security: Whitelist valid sampler modules
  defp safe_sampler_atom(str) do
    case str do
      "Scout.Sampler.RandomSearch" -> {:ok, Scout.Sampler.RandomSearch}
      "Scout.Sampler.TPE" -> {:ok, Scout.Sampler.TPE}  
      "Scout.Sampler.GridSearch" -> {:ok, Scout.Sampler.GridSearch}
      "Scout.Sampler.BayesOpt" -> {:ok, Scout.Sampler.BayesOpt}
      "Elixir.Scout.Sampler.RandomSearch" -> {:ok, Scout.Sampler.RandomSearch}
      "Elixir.Scout.Sampler.TPE" -> {:ok, Scout.Sampler.TPE}
      "Elixir.Scout.Sampler.GridSearch" -> {:ok, Scout.Sampler.GridSearch}
      "Elixir.Scout.Sampler.BayesOpt" -> {:ok, Scout.Sampler.BayesOpt}
      _ -> :error
    end
  end
  
  # Security: Whitelist valid study modules (expand as needed)
  defp safe_module_atom(str) do
    # Only allow modules that are already loaded and follow naming pattern
    try do
      atom = String.to_existing_atom(str)
      # Additional validation - must be in allowed namespace  
      if module_safe?(atom), do: {:ok, atom}, else: :error
    rescue
      ArgumentError -> :error
    end
  end
  
  # Validate module is in safe namespace
  defp module_safe?(module) do
    str = Atom.to_string(module)
    # Allow user-defined study modules and test modules
    String.starts_with?(str, "Elixir.") and 
    (String.contains?(str, "Study") or String.contains?(str, "Example") or String.contains?(str, "Test"))
  end

  defp now, do: System.system_time(:millisecond)
end
