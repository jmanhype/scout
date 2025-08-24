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
    # Set random seed if provided
    if state.seed do
      :rand.seed(:exsplus, {state.seed, ix, 42})
    end
    
    # Get the search space specification
    spec = space_fun.(ix)
    
    # Sample each parameter
    params = for {param_name, param_spec} <- spec, into: %{} do
      value = sample_parameter(param_spec)
      {param_name, value}
    end
    
    {params, state}
  end
  
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