defmodule Scout.Sampler.RandomSearch do
  @behaviour Scout.Sampler
  @moduledoc "Uniform random sampler."
  
  def init(opts), do: opts || %{}
  
  def next(space_fun, ix, _history, state) do
    spec = space_fun.(ix)
    params = Scout.SearchSpace.sample(spec)
    {params, state}
  end
end
