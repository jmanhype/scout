defmodule Scout.Study do
  @enforce_keys [:id, :goal, :max_trials, :parallelism, :search_space, :objective]
  defstruct [:id, :goal, :max_trials, :parallelism,
             :sampler, :sampler_opts, :pruner, :pruner_opts,
             :search_space, :objective, seed: nil, metadata: %{}]
end
