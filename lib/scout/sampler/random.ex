defmodule Scout.Sampler.Random do
  @moduledoc """
  Random sampling for Scout - required by TPE and other samplers.
  Falls back to RandomSearch functionality.
  """
  
  @behaviour Scout.Sampler
  
  @impl true
  def init(opts) do
    %{
      seed: Map.get(opts, :seed)
    }
  end
  
  @impl true
  def next(space_fun, ix, _history, state) do
    # FIXED: Use isolated RNG state instead of global process seeding
    rng_state = if state.seed do
      # Create isolated RNG state for this trial
      :rand.seed_s(:exsplus, {state.seed, ix, 42})
    else
      # Create a default seed if process hasn't been seeded
      case :rand.export_seed() do
        :undefined -> :rand.seed_s(:exsplus, {:erlang.monotonic_time(), :erlang.unique_integer(), ix})
        seed -> seed
      end
    end
    
    # Get the search space specification
    spec = space_fun.(ix)
    
    # Sample each parameter using isolated RNG
    {params, _final_rng} = Enum.map_reduce(spec, rng_state, fn {param_name, param_spec}, rng ->
      {value, new_rng} = sample_parameter_with_rng(param_spec, rng)
      {{param_name, value}, new_rng}
    end)
    
    {Map.new(params), state}
  end
  
  # FIXED: RNG-stateful parameter sampling (doesn't modify process RNG)
  defp sample_parameter_with_rng({:uniform, min, max}, rng_state) when is_number(min) and is_number(max) do
    {rand_val, new_rng} = :rand.uniform_s(rng_state)
    {min + rand_val * (max - min), new_rng}
  end
  
  defp sample_parameter_with_rng({:log_uniform, min, max}, rng_state) when is_number(min) and is_number(max) do
    {rand_val, new_rng} = :rand.uniform_s(rng_state)
    log_min = :math.log(min)
    log_max = :math.log(max)
    {:math.exp(log_min + rand_val * (log_max - log_min)), new_rng}
  end
  
  defp sample_parameter_with_rng({:int, min, max}, rng_state) when is_integer(min) and is_integer(max) do
    {rand_val, new_rng} = :rand.uniform_s(max - min + 1, rng_state)
    {min + rand_val - 1, new_rng}
  end
  
  defp sample_parameter_with_rng({:choice, choices}, rng_state) when is_list(choices) and length(choices) > 0 do
    {rand_idx, new_rng} = :rand.uniform_s(length(choices), rng_state)
    {Enum.at(choices, rand_idx - 1), new_rng}
  end
  
  defp sample_parameter_with_rng(_spec, rng_state) do
    # Fallback for unknown specifications
    :rand.uniform_s(rng_state)
  end
  
  # Legacy functions for backward compatibility (deprecated - use RNG-stateful versions)
  defp sample_parameter({:uniform, min, max}) when is_number(min) and is_number(max) do
    min + :rand.uniform() * (max - min)
  end
  
  defp sample_parameter({:log_uniform, min, max}) when is_number(min) and is_number(max) do
    log_min = :math.log(min)
    log_max = :math.log(max)
    :math.exp(log_min + :rand.uniform() * (log_max - log_min))
  end
  
  defp sample_parameter({:int, min, max}) when is_integer(min) and is_integer(max) do
    min + :rand.uniform(max - min + 1) - 1
  end
  
  defp sample_parameter({:choice, choices}) when is_list(choices) and length(choices) > 0 do
    Enum.random(choices)
  end
  
  defp sample_parameter(_spec) do
    # Fallback for unknown specifications
    :rand.uniform()
  end
end