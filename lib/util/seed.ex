
defmodule Scout.Util.Seed do
  @moduledoc "Deterministic per-study/per-trial RNG seeding."
  @doc "Returns a per-trial triad seed from {study_id, trial_ix, base_seed}"
  def seed_for(study_id, ix, base_seed) do
    <<a::32, b::32, c::32>> =
      :crypto.hash(:sha256, "#{study_id}:#{ix}:#{base_seed}")
      |> binary_part(0, 12)

    {:exsss, {a, b, c}}
  end
end
