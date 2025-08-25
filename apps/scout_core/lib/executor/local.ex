
defmodule Scout.Executor.Local do
  @moduledoc "Local in-process executor using Task.async_stream (one-shot objective)."
  
  @behaviour Scout.Executor
  
  alias Scout.{Store, Telemetry, Util.Seed}

  @impl Scout.Executor
  def run(study) do
    base_seed = study.seed || :erlang.unique_integer([:positive])
    :ok = Store.put_study(Map.merge(Map.take(study, [:id, :goal, :max_trials, :parallelism]), %{seed: base_seed}))
    Telemetry.study_created(study.id, study.goal, %{executor: :local})

    sampler_mod = (study.sampler || Scout.Sampler.RandomSearch)
    sampler_state = sampler_mod.init(Map.merge(study.sampler_opts || %{}, %{goal: study.goal}))

    trials =
      0..(study.max_trials - 1)
      |> Task.async_stream(fn ix -> run_one(study, ix, base_seed, sampler_mod, sampler_state) end,
            max_concurrency: study.parallelism, timeout: :infinity)
      |> Enum.map(fn {:ok, t} -> t end)

    best = pick_best(trials, study.goal)
    best_score = if best, do: best.score, else: 0.0
    Telemetry.study_completed(study.id, %{duration_ms: 0, trial_count: length(trials), best_score: best_score}, %{best_trial_id: if(best, do: best.id, else: nil)})
    best_to_result(best)
  end

  defp run_one(study, ix, base_seed, sampler_mod, sampler_state) do
    {:exsss, seed_tuple} = Seed.seed_for(study.id, ix, base_seed)
    :rand.seed(:exsss, seed_tuple)
    history = Scout.Store.list_trials(study.id)
    {params, _state2} = sampler_mod.next(study.search_space, ix, history, sampler_state)

    # Purpose: Use Store.start_trial/3 instead of crafting %Trial{} directly
    {:ok, id} = Scout.Store.start_trial(study.id, params, 0)
    Telemetry.trial_started(study.id, id, ix, params)
    
    # Build minimal map for return value only
    started_at = now()
    t = %{id: id, study_id: study.id, params: params, bracket: 0, started_at: started_at}

    result =
      case safe_objective(study.objective, params) do
        {:ok, score, metrics} -> {:ok, score, metrics}
        {:ok, score} when is_number(score) -> {:ok, score, %{}}
        score when is_number(score) -> {:ok, score, %{}}
        {:error, reason} -> {:error, reason}
        other -> {:error, {:invalid_objective_return, other}}
      end

    t2 =
      case result do
        {:ok, score, metrics} ->
          # Purpose: Use Store.finish_trial/4 facade method
          :ok = Scout.Store.finish_trial(study.id, id, score, metrics)
          dur = now() - t.started_at
          Telemetry.trial_completed(study.id, id, score, dur * 1000, :completed)
          Map.merge(t, %{status: :completed, score: score, metrics: metrics, completed_at: now()})
        {:error, reason} ->
          # Purpose: Use Store.fail_trial/3 facade method
          :ok = Scout.Store.fail_trial(study.id, id, inspect(reason))
          dur = now() - t.started_at
          Telemetry.trial_completed(study.id, id, 0.0, dur * 1000, :failed, %{error: inspect(reason)})
          Map.merge(t, %{status: :failed, error: inspect(reason), completed_at: now()})
      end
    t2
  end

  defp safe_objective(fun, params) when is_function(fun, 1) do
    try do fun.(params) rescue e -> {:error, e} catch :exit, r -> {:error, {:exit, r}} end
  end

  defp pick_best(trials, :maximize), do: Enum.max_by(trials, & &1.score, fn -> nil end)
  defp pick_best(trials, :minimize), do: Enum.min_by(trials, & &1.score, fn -> nil end)
  defp best_to_result(%{params: p, score: s}), do: {:ok, %{best_params: p, best_score: s}}
  defp best_to_result(_), do: {:error, :no_trials}
  defp now, do: System.system_time(:millisecond)
end
