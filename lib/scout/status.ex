defmodule Scout.Status do
  @moduledoc """
  Bracket/rung status for Hyperband.
  """
  alias Scout.Store

  def status(study_id) do
    with {:ok, _} <- Store.get_study(study_id) do
      trials = Store.list_trials(study_id)
      brackets = trials |> Enum.map(& &1.bracket) |> Enum.uniq() |> Enum.sort()
      per_bracket =
        for b <- brackets, into: %{} do
          rungs = rungs_for(trials, b)
          {b, %{
            rungs: for r <- rungs, into: %{} do
              obs = Store.observations_at_rung(study_id, b, r)
              ids = Enum.map(obs, &elem(&1, 0)) |> MapSet.new()
              %{pruned: pruned, running: running, done: done} = classify(trials, ids, b)
              {r, %{observations: length(obs), pruned: pruned, running: running, completed: done}}
            end
          }}
        end
      {:ok, %{study_id: study_id, brackets: per_bracket}}
    else
      _ -> {:error, :not_found}
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
    done = Enum.count(tr_b, fn t -> t.status == :succeeded and MapSet.member?(seen_ids, t.id) end)
    %{pruned: pruned, running: running, done: done}
  end
end
