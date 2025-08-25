defmodule Scout.Pruner.Hyperband do
  @behaviour Scout.Pruner
  @moduledoc """
  Hyperband pruner (brackets + SHA rungs).

  * `eta` controls downsampling per rung.
  * `max_resource` is the maximum rung count (or unit of budget) the objective can report.
  * We compute brackets s = 0..s_max where s_max = floor(log_eta(max_resource)).
  * For bracket s, the number of rungs is s+1 with SHA keep fraction 1/eta per rung.

  This pruner expects the **iterative executor** to:
    1) assign bracket per trial via `assign_bracket/2`
    2) call `report_fun.(score, rung)` with 0-based rung per bracket

  Pruning decision at rung r:
    - Gather peer scores at the same (study_id, bracket, rung)
    - Keep top fraction `1/eta` (goal-aware); else prune.
  """
  alias Scout.Store

  def init(opts) do
    eta = Map.get(opts, :eta, 3)
    max_resource = Map.get(opts, :max_resource, 81)
    s_max = trunc(:math.log(max_resource) / :math.log(eta)) |> max(0)
    brackets = Enum.to_list(0..s_max)
    %{
      eta: eta,
      max_resource: max_resource,
      s_max: s_max,
      brackets: brackets,
      warmup_peers: Map.get(opts, :warmup_peers, 6)
    }
  end

  def assign_bracket(ix, state) do
    {Enum.at(state.brackets, rem(ix, length(state.brackets))), state}
  end

  def keep?(trial_id, scores_so_far, rung, %{study_id: sid, goal: goal, bracket: bracket}, state) do
    peers = Store.observations_at_rung(sid, bracket, rung)
    if length(peers) < state.warmup_peers or scores_so_far == [] do
      {true, state}
    else
      keep_fraction = 1.0 / state.eta
      sorted =
        case goal do
          :minimize -> Enum.sort_by(peers, fn {_id, s} -> s end, :asc)
          _ -> Enum.sort_by(peers, fn {_id, s} -> s end, :desc)
        end
      k = max(trunc(length(sorted) * keep_fraction), 1)
      top_ids = sorted |> Enum.take(k) |> Enum.map(&elem(&1, 0))
      {Enum.member?(top_ids, trial_id), state}
    end
  end
end
