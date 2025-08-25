defmodule Scout.Executor.Iterative do
  @moduledoc """
  Iterative executor with pruning support (Hyperband/SHA).
  Objective arity 2: `fn params, report_fun -> ... end`
  """
  
  @behaviour Scout.Executor
  
  alias Scout.Telemetry
  
  # Use ETS store by default
  @store_impl Application.compile_env(:scout, :store, Scout.Store)

  @impl Scout.Executor
  def run(study) do
    # Don't pollute global RNG state - seed will be set per-trial
    :ok = @store_impl.put_study(%{id: study.id, goal: study.goal})

    Telemetry.study_created(study.id, study.goal, %{executor: :iterative, max_trials: study.max_trials})

    sampler = (study.sampler || Scout.Sampler.RandomSearch)
    s_state = sampler.init(Map.merge(study.sampler_opts || %{}, %{goal: study.goal}))

    {p_state, _} =
      if study.pruner do
        {:ok, study.pruner.init(study.pruner_opts || %{})}
      else
        {:ok, nil}
      end

    tasks =
      for ix <- 0..(study.max_trials - 1) do
        Task.Supervisor.async_nolink(Scout.TaskSupervisor, fn -> run_one(study, ix, sampler, s_state, study.pruner, p_state) end)
      end

    results = Enum.map(tasks, &Task.await(&1, :infinity))
    best = pick_best(results, study.goal)
    best_score = if best, do: best.score, else: 0.0
    Telemetry.study_completed(study.id, %{duration_ms: 0, trial_count: length(results), best_score: best_score}, %{best_trial_id: if(best, do: best.id, else: nil)})
    {:ok, %{best_params: best && best.params, best_score: best && best.score, trials: results}}
  end

  defp run_one(study, ix, sampler, s_state, pruner_mod, p_state) do
    history = @store_impl.list_trials(study.id)
    {params, _} = sampler.next(study.search_space, ix, history, s_state)

    # Pruner: assign bracket
    {bracket, p_state2} = if pruner_mod, do: pruner_mod.assign_bracket(ix, p_state), else: {0, p_state}

    # Purpose: Use Store.start_trial/3 instead of crafting %Trial{} directly
    {:ok, id} = @store_impl.start_trial(study.id, params, bracket)
    Telemetry.trial_started(study.id, id, ix, params, %{bracket: bracket})
    
    # Build minimal trial struct for return value only
    t = %{id: id, study_id: study.id, params: params, bracket: bracket}

    ctx = %{study_id: study.id, goal: study.goal, bracket: bracket}
    report_fun = fn score, rung ->
      @store_impl.record_observation(study.id, id, bracket, rung, score)
      if pruner_mod do
        {keep, _} = pruner_mod.keep?(id, [score], rung, ctx, p_state2)
        if keep, do: :continue, else: (
          # Purpose: Use Store.prune_trial/3 facade method
          :ok = @store_impl.prune_trial(study.id, id, score);
          Telemetry.trial_pruned(study.id, id, rung, score, bracket, "below_percentile");
          :prune
        )
      else
        :continue
      end
    end

    result =
      case safe_objective(study.objective, params, report_fun) do
        {:ok, score, m} -> {:ok, score, m}
        {:ok, score} when is_number(score) -> {:ok, score, %{}}
        score when is_number(score) -> {:ok, score, %{}}
        score when is_list(score) -> 
          # Handle multi-objective returns by taking the sum (simple aggregation)
          aggregated_score = Enum.sum(score)
          {:ok, aggregated_score, %{objectives: score}}
        {:pruned, score} -> {:pruned, score}
        {:error, reason} -> {:error, reason}
        other -> {:error, {:invalid_objective_return, other}}
      end

    case result do
      {:ok, score, m} ->
        # Purpose: Use Store.finish_trial/4 facade method
        :ok = @store_impl.finish_trial(study.id, id, score, m)
        started_at = now() # Approximate since we don't have original
        dur = 1000 # Default duration
        Telemetry.trial_completed(study.id, id, score, dur, :completed)
        Map.merge(t, %{status: :completed, score: score, metrics: m, completed_at: now()})
      {:pruned, score} ->
        # Purpose: Use Store.prune_trial/3 facade method
        :ok = @store_impl.prune_trial(study.id, id, score)
        Map.merge(t, %{status: :pruned, score: score, completed_at: now()})
      {:error, reason} ->
        # Purpose: Use Store.fail_trial/3 facade method
        :ok = @store_impl.fail_trial(study.id, id, inspect(reason))
        dur = 1000 # Default duration
        Telemetry.trial_completed(study.id, id, 0.0, dur, :failed, %{error: inspect(reason)})
        Map.merge(t, %{status: :failed, error: inspect(reason), completed_at: now()})
    end
  end

  defp safe_objective(fun, params, report_fun) when is_function(fun, 2) do
    try do fun.(params, report_fun) rescue e -> {:error, e} catch :exit, r -> {:error, {:exit, r}} end
  end
  defp safe_objective(fun, params, _report_fun) when is_function(fun, 1) do
    try do fun.(params) rescue e -> {:error, e} catch :exit, r -> {:error, {:exit, r}} end
  end

  defp pick_best(trials, :maximize), do: Enum.max_by(trials, & &1.score, fn -> nil end)
  defp pick_best(trials, :minimize), do: Enum.min_by(trials, & &1.score, fn -> nil end)

  defp now, do: System.system_time(:millisecond)
end
