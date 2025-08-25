
defmodule Scout.Pruner.SuccessiveHalving do
  @behaviour Scout.Pruner
  @moduledoc """
  Successive Halving (SHA). At rung `r`, we keep fraction `eta^{-r}` of trials based on their
  most recent score at that rung. Uses study trials as the population; requires enough peers
  at the rung to be meaningful, otherwise always keep.
  """

  @defaults %{eta: 3, warmup_trials: 12, min_peers: 6}

  def init(opts), do: Map.merge(@defaults, Map.new(opts || %{}))

  def assign_bracket(_trial_index, state) do
    # For successive halving, we can use a simple bracket assignment
    # based on trial index - all trials go to bracket 0 for simplicity
    {0, state}
  end

  def keep?(_trial_id, scores_so_far, rung, %{goal: goal, study_id: study_id}, state) do
    total_trials = length(Scout.Store.list_trials(study_id))
    if total_trials < state.warmup_trials or length(scores_so_far) == 0 do
      {true, state}
    else
      peers =
        Scout.Store.list_trials(study_id)
        |> Enum.filter(&is_number(&1.score))

      if length(peers) < state.min_peers do
        {true, state}
      else
        keep_fraction = :math.pow(state.eta, -max(rung, 0))
        ranked =
          case goal do
            :minimize -> Enum.sort_by(peers, & &1.score, :asc)
            _ -> Enum.sort_by(peers, & &1.score, :desc)
          end

        cutoff_ix = max(trunc(length(ranked) * keep_fraction) - 1, 0)
        cutoff_ix = min(cutoff_ix, length(ranked) - 1)
        cutoff_score = Enum.at(ranked, cutoff_ix).score
        current = List.last(scores_so_far) || hd(scores_so_far)
        keep =
          case goal do
            :minimize -> current <= cutoff_score
            _ -> current >= cutoff_score
          end
        {keep, state}
      end
    end
  end
end
