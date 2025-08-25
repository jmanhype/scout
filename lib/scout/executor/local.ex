
defmodule Scout.Executor.Local do
  @moduledoc "Local in-process executor using Task.async_stream (one-shot objective)."
  
  @behaviour Scout.Executor
  
  alias Scout.{Store, Trial, Telemetry, Util.Seed}

  @impl Scout.Executor
  def run(study) do
    base_seed = study.seed || :erlang.unique_integer([:positive])
    :ok = Store.put_study(Map.merge(Map.take(study, [:id, :goal, :max_trials, :parallelism]), %{seed: base_seed}))
    Telemetry.study_event(:start, %{}, %{study: study.id, executor: :local})

    sampler_mod = (study.sampler || Scout.Sampler.RandomSearch)
    sampler_state = sampler_mod.init(Map.merge(study.sampler_opts || %{}, %{goal: study.goal}))

    trials =
      0..(study.max_trials - 1)
      |> Task.async_stream(fn ix -> run_one(study, ix, base_seed, sampler_mod, sampler_state) end,
            max_concurrency: study.parallelism, timeout: :infinity)
      |> Enum.map(fn {:ok, t} -> t end)

    best = pick_best(trials, study.goal)
    Telemetry.study_event(:stop, %{n: length(trials)}, %{study: study.id, best: best})
    best_to_result(best)
  end

  defp run_one(study, ix, base_seed, sampler_mod, sampler_state) do
    :rand.seed(Seed.seed_for(study.id, ix, base_seed))
    history = Scout.Store.list_trials(study.id)
    {params, _state2} = sampler_mod.next(study.search_space, ix, history, sampler_state)

    id = Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
    t = %Trial{id: id, study_id: study.id, params: params, bracket: 0, status: :running, started_at: now(), seed: elem(Seed.seed_for(study.id, ix, base_seed), 1)}
    {:ok, _} = Scout.Store.add_trial(study.id, t)
    Telemetry.trial_event(:start, %{ix: ix}, %{study: study.id, trial_id: id, params: params})

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
          _ = Scout.Store.update_trial(study.id, id, %{status: :succeeded, score: score, metrics: metrics, finished_at: now()})
          Telemetry.trial_event(:stop, %{score: score}, %{study: study.id, trial_id: id})
          %Trial{t | status: :succeeded, score: score, metrics: metrics, finished_at: now()}
        {:error, reason} ->
          _ = Scout.Store.update_trial(study.id, id, %{status: :failed, error: inspect(reason), finished_at: now()})
          Telemetry.trial_event(:error, %{}, %{study: study.id, trial_id: id, reason: inspect(reason)})
          %Trial{t | status: :failed, error: inspect(reason), finished_at: now()}
      end
    t2
  end

  defp safe_objective(fun, params) when is_function(fun, 1) do
    try do fun.(params) rescue e -> {:error, e} catch :exit, r -> {:error, {:exit, r}} end
  end

  defp pick_best(trials, :maximize), do: Enum.max_by(trials, & &1.score, fn -> nil end)
  defp pick_best(trials, :minimize), do: Enum.min_by(trials, & &1.score, fn -> nil end)
  defp best_to_result(%Trial{params: p, score: s}), do: {:ok, %{best_params: p, best_score: s}}
  defp best_to_result(_), do: {:error, :no_trials}
  defp now, do: System.system_time(:millisecond)
end
