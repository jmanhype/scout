defmodule Scout.Sampler do
  @callback init(map()) :: map()
  @callback next((non_neg_integer() -> map()), non_neg_integer(), list(), map()) :: {map(), map()}
end
