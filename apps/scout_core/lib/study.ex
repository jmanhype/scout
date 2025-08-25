defmodule Scout.Study do
  @enforce_keys [:id, :goal, :max_trials, :parallelism, :search_space, :objective]
  defstruct [:id, :goal, :max_trials, :parallelism,
             :sampler, :sampler_opts, :pruner, :pruner_opts,
             :search_space, :objective, :executor,
             seed: nil, metadata: %{}]
  
  @doc """
  Optimize a study with an objective function (like optuna study.optimize).
  """
  def optimize(study, objective, opts \\ []) when is_map(study) and is_function(objective) do
    # Convert the study map to parameters for Scout.Easy.optimize
    n_trials = Keyword.get(opts, :n_trials, 10)
    direction = study[:direction] || study["direction"] || :minimize
    sampler = study[:sampler] || study["sampler"] || :random
    
    # Create a simple search space for the objective - this is a placeholder
    # In a real implementation, this would be derived from the study or passed explicitly
    search_space = %{x: {:uniform, -10, 10}}
    
    # Use Scout.Easy.optimize to run the optimization
    Scout.Easy.optimize(objective, search_space,
      n_trials: n_trials,
      direction: direction,
      sampler: sampler,
      study_name: study[:name] || study[:study_name] || "unknown_study"
    )
  end
end
