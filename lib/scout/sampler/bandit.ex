
defmodule Scout.Sampler.Bandit do
  @behaviour Scout.Sampler
  @moduledoc "ε-greedy + UCB1 over a candidate pool; bucketized numeric params."
  @defaults %{epsilon: 0.1, ucb_c: 2.0, bins: 5, pool: 24}

  def init(opts), do: Map.merge(@defaults, Map.new(opts || %{}))

  def next(space_fun, ix, history, state) do
    eps = state.epsilon
    c = state.ucb_c
    pool_n = state.pool
    candidates = for j <- 1..pool_n, do: space_fun.(ix * 10_000 + j)

    stats = bucket_stats(Enum.take(history, 1000), state.bins)
    pick =
      if :rand.uniform() < eps or map_size(stats) == 0 do
        Enum.random(candidates)
      else
        total = max(Enum.reduce(stats, 0, fn {_k, %{n: n}}, acc -> acc + n end), 1)
        Enum.max_by(candidates, fn params ->
          {key, _} = bucket_key(params, state.bins)
          %{n: n, mean: mean} = Map.get(stats, key, %{n: 0, mean: 0.0})
          n = max(n, 1)
          mean + c * :math.sqrt(:math.log(total) / n)
        end)
      end
    {pick, state}
  end

  defp bucket_stats(history, bins) do
    Enum.reduce(history, %{}, fn %{params: params, score: score}, acc ->
      {key, _} = bucket_key(params, bins)
      Map.update(acc, key, %{n: 1, mean: score}, fn %{n: n, mean: m} ->
        n2 = n + 1; %{n: n2, mean: m + (score - m) / n2}
      end)
    end)
  end

  defp bucket_key(params, bins) do
    keys = params |> Map.keys() |> Enum.sort()
    buckets =
      for k <- keys do
        v = Map.fetch!(params, k)
        cond do
          is_number(v) -> {:num, k, min(bins-1, max(0, trunc(v * bins)))}
          is_binary(v) or is_atom(v) or is_integer(v) -> {:cat, k, v}
          true -> {:raw, k, v}
        end
      end
    {List.to_tuple(buckets), buckets}
  end
end
