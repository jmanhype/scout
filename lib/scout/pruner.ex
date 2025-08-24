defmodule Scout.Pruner do
  @type ctx :: %{study_id: binary(), goal: :maximize | :minimize, bracket: non_neg_integer()}
  @callback init(map()) :: map()
  @callback assign_bracket(non_neg_integer(), map()) :: {non_neg_integer(), map()}
  @callback keep?(trial_id :: binary(), scores_so_far :: [number()], rung :: non_neg_integer(), ctx, map()) :: {boolean(), map()}
end
