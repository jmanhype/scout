
defmodule Scout.Executor.Oban do
  @moduledoc """
  Durable distributed executor powered by Oban.
  Requirements:
    * You must configure Postgres and Oban in config (see config.sample.exs).
    * For full durability across restarts, define a **Study module**. The Oban worker
      loads objective/search_space from that module (callbacks), not from closures.
  """
  alias Scout.{Store, Telemetry}

  def run(%{id: id} = study) do
    :ok = Store.put_study(study)
    Telemetry.study_event(:start, %{}, %{study: id, executor: :oban})
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
  alias Scout.{Store, Trial, Telemetry, Util.Seed}

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

    id = Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
    t = %Trial{id: id, study_id: study_id, params: params, bracket: 0, status: :running, started_at: now(), seed: elem(Seed.seed_for(study_id, ix, base_seed), 1)}
    {:ok, _} = Store.add_trial(study_id, t)
    Telemetry.trial_event(:start, %{ix: ix}, %{study: study_id, trial_id: id, params: params})

    goal = String.to_atom(args["goal"] || "maximize")

    result =
      case :erlang.fun_info(objective_fun)[:arity] do
        2 -> run_iterative(objective_fun, pruner_mod, pruner_state, study_id, id, params, goal)
        _ -> run_oneshot(objective_fun, params)
      end

    case result do
      {:ok, score, metrics} ->
        Store.update_trial(id, %{status: :succeeded, score: score, metrics: metrics, finished_at: now()})
        Telemetry.trial_event(:stop, %{score: score}, %{study: study_id, trial_id: id})
      {:error, reason} ->
        Store.update_trial(id, %{status: :failed, error: inspect(reason), finished_at: now()})
        Telemetry.trial_event(:error, %{}, %{study: study_id, trial_id: id, reason: inspect(reason)})
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
        if keep, do: :continue, else: (Scout.Telemetry.trial_event(:prune, %{rung: rung, score: score}, %{study: study_id, trial_id: trial_id}); :prune)
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
    mod = try do
      String.to_existing_atom(mod_str)
    rescue
      _ -> String.to_atom(mod_str)
    end
    
    if function_exported?(mod, :search_space, 1) and (function_exported?(mod, :objective, 1) or function_exported?(mod, :objective, 2)) do
      {:ok, {&mod.search_space/1, &mod.objective/1}}
    else
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
        try do
          String.to_existing_atom(str)
        rescue
          _ -> String.to_atom(str)
        end
    end
  end

  defp now, do: System.system_time(:millisecond)
end
