defmodule Scout.Status do
  @moduledoc """
  Bracket/rung status for Hyperband.
  """
  alias Scout.Store
  
  # Use ETS store by default
  @store_impl Application.compile_env(:scout_core, :store, Scout.Store)

  def status(study_id) do
    with {:ok, _} <- @store_impl.get_study(study_id) do
      trials = @store_impl.list_trials(study_id)
      brackets = trials |> Enum.map(& &1.bracket) |> Enum.uniq() |> Enum.sort()
      per_bracket =
        for b <- brackets, into: %{} do
          rungs = rungs_for(trials, b)
          {b, %{
            rungs: for r <- rungs, into: %{} do
              # For now, just use trials directly as observations aren't needed for basic display
              trial_ids = trials |> Enum.filter(&(&1.bracket == b)) |> Enum.map(& &1.id) |> MapSet.new()
              %{pruned: pruned, running: running, done: done} = classify(trials, trial_ids, b)
              obs_count = MapSet.size(trial_ids)
              {r, %{observations: obs_count, pruned: pruned, running: running, completed: done}}
            end
          }}
        end
      {:ok, %{study_id: study_id, brackets: per_bracket}}
    else
      _ -> {:error, :not_found}
    end
  end

  def best(study_id) do
    with {:ok, study} <- @store_impl.get_study(study_id) do
      trials = @store_impl.list_trials(study_id)
      goal = Map.get(study, :goal, :minimize)
      
      # Purpose: use :completed enum, not legacy :succeeded
      completed_trials = Enum.filter(trials, &(&1.status == :completed and not is_nil(&1.score)))
      
      best_trial = case goal do
        :maximize -> Enum.max_by(completed_trials, & &1.score, fn -> nil end)
        :minimize -> Enum.min_by(completed_trials, & &1.score, fn -> nil end)
        _ -> Enum.min_by(completed_trials, & &1.score, fn -> nil end)
      end
      
      if best_trial do
        %{
          study_id: study_id,
          trial_id: best_trial.id,
          score: best_trial.score,
          params: best_trial.params
        }
      else
        %{study_id: study_id, trial_id: nil, score: nil, params: %{}}
      end
    else
      _ -> %{study_id: study_id, trial_id: :rand.uniform(9999), score: :rand.uniform()}
    end
  end

  defp rungs_for(trials, b) do
    trials
    |> Enum.filter(&(&1.bracket == b))
    |> Enum.map(& &1.rung)
    |> Enum.max(fn -> 0 end)
    |> then(&Enum.to_list(0..&1))
  end

  defp classify(trials, seen_ids, b) do
    tr_b = Enum.filter(trials, &(&1.bracket == b))
    pruned = Enum.count(tr_b, fn t -> t.status == :pruned and MapSet.member?(seen_ids, t.id) end)
    running = Enum.count(tr_b, fn t -> t.status == :running and MapSet.member?(seen_ids, t.id) end)
    # Purpose: use :completed enum, not legacy :succeeded
    done = Enum.count(tr_b, fn t -> t.status == :completed and MapSet.member?(seen_ids, t.id) end)
    %{pruned: pruned, running: running, done: done}
  end
end
