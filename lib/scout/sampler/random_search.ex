defmodule Scout.Sampler.RandomSearch do
  @behaviour Scout.Sampler
  @moduledoc "Uniform random sampler."
  
  def init(opts), do: opts || %{}
  
  def next(space_or_fun, _ix, _history, state) do
    # Handle both function and direct spec
    spec = if is_function(space_or_fun), do: space_or_fun.(), else: space_or_fun
    params = Scout.SearchSpace.sample(spec)
    {params, state}
  end
end
