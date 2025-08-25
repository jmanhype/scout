defmodule Scout.SearchSpace do
  @moduledoc """
  Handles search space specifications and sampling.
  Converts search space specs into actual sampled values.
  """

  def sample(spec) when is_map(spec) do
    spec
    |> Enum.map(fn {key, value} -> {key, sample_param(value)} end)
    |> Map.new()
  end

  defp sample_param({:uniform, min, max}) do
    min + :rand.uniform() * (max - min)
  end

  defp sample_param({:log_uniform, min, max}) do
    log_min = :math.log(min)
    log_max = :math.log(max)
    :math.exp(log_min + :rand.uniform() * (log_max - log_min))
  end

  defp sample_param({:choice, choices}) do
    Enum.random(choices)
  end

  defp sample_param({:int, min, max}) do
    min + :rand.uniform(max - min + 1) - 1
  end

  defp sample_param({:discrete_uniform, low, high, step}) do
    n_steps = trunc((high - low) / step)
    step_index = :rand.uniform(n_steps + 1) - 1
    low + step * step_index
  end

  defp sample_param(value) when is_number(value) do
    value
  end

  defp sample_param(value), do: value
end