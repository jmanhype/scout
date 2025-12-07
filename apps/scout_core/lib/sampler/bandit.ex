
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
          # UCB1 formula: mean + c * sqrt(log(total) / n)
          # Ensure mean is a valid number, default to 0.0
          safe_mean = if is_number(mean) and is_finite(mean), do: mean, else: 0.0
          exploration = c * :math.sqrt(:math.log(total) / n)
          safe_mean + exploration
        end)
      end
    {pick, state}
  end

  defp bucket_stats(history, bins) do
    Enum.reduce(history, %{}, fn trial, acc ->
      # Skip trials without valid scores
      score = Map.get(trial, :score)
      params = Map.get(trial, :params)

      cond do
        not is_map(params) -> acc
        not is_number(score) -> acc
        not is_finite(score) -> acc
        true ->
          {key, _} = bucket_key(params, bins)
          Map.update(acc, key, %{n: 1, mean: score}, fn %{n: n, mean: m} ->
            n2 = n + 1
            new_mean = m + (score - m) / n2
            %{n: n2, mean: if(is_finite(new_mean), do: new_mean, else: m)}
          end)
      end
    end)
  end

  defp is_finite(x) when is_number(x) do
    x == x and x != :pos_infinity and x != :neg_infinity
  end
  defp is_finite(_), do: false

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
