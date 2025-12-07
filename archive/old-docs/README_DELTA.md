
# Scout v0.3a delta

This patch adds:
- **TPE sampler (univariate KDE)** at `Scout.Sampler.TPE`
- Stronger **Successive Halving** pruning logic
- Executors now pass `goal` into sampler state for correct ranking

## Usage
```elixir
study = %{
  id: "tpe-demo-#{:erlang.unique_integer([:positive])}",
  goal: :maximize,
  max_trials: 50,
  parallelism: 8,
  sampler: Scout.Sampler.TPE,
  sampler_opts: %{gamma: 0.15, n_candidates: 32, min_obs: 20},
  pruner: Scout.Pruner.SuccessiveHalving,
  search_space: fn _ -> %{temperature: :rand.uniform(), top_p: :rand.uniform()} end,
  objective: fn %{temperature: t, top_p: p} ->
    {:ok, 1.0 - :math.pow(t - 0.2, 2) - :math.pow(p - 0.9, 2), %{}}
  end
}
{:ok, result} = Scout.StudyRunner.run(study)
IO.inspect(result, label: "BEST")
```
