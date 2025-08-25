defmodule Scout.Util.RNG do
  @moduledoc """
  Deterministic and isolated random number generation for Scout.
  
  CRITICAL FIXES:
  - Never mutates global :rand state
  - Deterministic seeding based on study_id + trial_index
  - Seed isolation prevents cross-contamination
  - Proper seed restoration to prevent side effects
  
  Usage:
      Scout.Util.RNG.with_seed(study_id, trial_index, fn ->
        # Your random operations here
        :rand.uniform()
      end)
  """

  require Logger

  @typedoc "Random seed tuple for :exsss algorithm"
  @type seed :: {non_neg_integer(), non_neg_integer(), non_neg_integer()}

  @doc """
  Generate deterministic seed from study ID and trial index.
  
  Uses cryptographic hash to ensure:
  - Same (study_id, index) always produces same seed
  - Different (study_id, index) produce uncorrelated seeds
  - Seeds are uniformly distributed
  """
  @spec seed_for(String.t(), non_neg_integer()) :: seed()
  def seed_for(study_id, trial_index) when is_binary(study_id) and is_integer(trial_index) and trial_index >= 0 do
    # Create deterministic input
    input = study_id <> <<trial_index::64>>
    
    # Hash to get uniform distribution
    hash = :crypto.hash(:sha256, input)
    
    # Extract three 32-bit seeds for :exsss algorithm
    <<a::32, b::32, c::32, _rest::binary>> = hash
    
    # Ensure no zero seeds (would break some algorithms)
    a = if a == 0, do: 1, else: a
    b = if b == 0, do: 1, else: b  
    c = if c == 0, do: 1, else: c
    
    {a, b, c}
  end

  @doc """
  Execute function with isolated random seed.
  
  Saves current global :rand state, sets deterministic seed,
  executes function, then restores original state.
  
  This prevents random operations from affecting global state
  or being affected by other concurrent operations.
  """
  @spec with_seed(String.t(), non_neg_integer(), (() -> result)) :: result when result: any()
  def with_seed(study_id, trial_index, fun) when is_function(fun, 0) do
    # Save current global random state
    old_state = :rand.export_seed()
    
    try do
      # Set our deterministic seed
      seed = seed_for(study_id, trial_index)
      :rand.seed(:exsss, seed)
      
      # Execute function with isolated seed
      result = fun.()
      
      Logger.debug("RNG operation completed for study=#{study_id} trial=#{trial_index}")
      result
    after
      # Always restore original state, even if function crashes
      _ = :rand.seed(old_state)
    end
  end

  @doc """
  Generate reproducible random sequence for testing.
  
  Returns a list of N random numbers for given study/trial.
  Useful for testing determinism and debugging.
  """
  @spec generate_sequence(String.t(), non_neg_integer(), pos_integer()) :: [float()]
  def generate_sequence(study_id, trial_index, count) when count > 0 do
    with_seed(study_id, trial_index, fn ->
      for _ <- 1..count, do: :rand.uniform()
    end)
  end

  @doc """
  Verify seed determinism by comparing sequences.
  
  Returns :ok if same (study_id, trial_index) produces identical sequences.
  Returns {:error, reason} if non-deterministic behavior detected.
  """
  @spec verify_determinism(String.t(), non_neg_integer(), pos_integer()) :: :ok | {:error, term()}
  def verify_determinism(study_id, trial_index, count \\ 100) do
    seq1 = generate_sequence(study_id, trial_index, count)
    seq2 = generate_sequence(study_id, trial_index, count)
    
    case seq1 == seq2 do
      true -> :ok
      false -> 
        Logger.error("RNG non-determinism detected for study=#{study_id} trial=#{trial_index}")
        {:error, :non_deterministic}
    end
  end

  @doc """
  Test isolation by verifying different seeds produce different sequences.
  
  Returns :ok if proper isolation detected.
  Returns {:error, reason} if sequences are identical (bad isolation).
  """
  @spec verify_isolation(String.t(), non_neg_integer(), non_neg_integer(), pos_integer()) :: :ok | {:error, term()}
  def verify_isolation(study_id, trial_index1, trial_index2, count \\ 100) 
      when trial_index1 != trial_index2 do
    seq1 = generate_sequence(study_id, trial_index1, count)
    seq2 = generate_sequence(study_id, trial_index2, count)
    
    case seq1 == seq2 do
      false -> :ok
      true ->
        Logger.error("RNG isolation failure: identical sequences for different trials")
        {:error, :poor_isolation}
    end
  end

  @doc """
  Generate seed for sampler state initialization.
  
  Samplers like TPE need their own deterministic initialization
  separate from trial-level randomness.
  """
  @spec sampler_seed(String.t(), atom()) :: seed()
  def sampler_seed(study_id, sampler_type) when is_atom(sampler_type) do
    input = study_id <> Atom.to_string(sampler_type) <> "_sampler_init"
    hash = :crypto.hash(:sha256, input)
    <<a::32, b::32, c::32, _::binary>> = hash
    
    # Ensure non-zero
    a = if a == 0, do: 1, else: a
    b = if b == 0, do: 1, else: b
    c = if c == 0, do: 1, else: c
    
    {a, b, c}
  end

  @doc """
  Execute function with sampler-specific seed isolation.
  """
  @spec with_sampler_seed(String.t(), atom(), (() -> result)) :: result when result: any()
  def with_sampler_seed(study_id, sampler_type, fun) when is_function(fun, 0) do
    old_state = :rand.export_seed()
    
    try do
      seed = sampler_seed(study_id, sampler_type)
      :rand.seed(:exsss, seed)
      fun.()
    after
      _ = :rand.seed(old_state)
    end
  end
end