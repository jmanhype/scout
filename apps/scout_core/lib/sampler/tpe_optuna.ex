defmodule Scout.Sampler.TPEOptuna do
  @behaviour Scout.Sampler
  @moduledoc """
  Optuna-aligned independent TPE sampler for parity benchmarks.

  Key choices to mirror Optuna defaults:
  - Independent KDE per parameter (no copula, no priors)
  - Bandwidth: Scott's rule (1.06 * sigma * n^(-1/5)) with small floor
  - Gamma: min(0.1, 1/sqrt(n_obs)) good/bad split
  - n_candidates: 64
  - min_obs: 10
  - Log-uniform sampled in log space; ints rounded
  """

  def init(opts) do
    %{
      min_obs: Map.get(opts, :min_obs, 10),
      n_candidates: Map.get(opts, :n_candidates, 64),
      goal: Map.get(opts, :goal, :minimize),
      seed: Map.get(opts, :seed),
      bw_floor: Map.get(opts, :bw_floor, 1.0e-3)
    }
  end

  def next(space_fun, ix, history, state) do
    if state.seed do
      :rand.seed(:exsplus, {state.seed, ix + 1, 999})
    end

    if length(history) < state.min_obs do
      # Random draw from spec
      spec = space_fun.(ix)
      params =
        Enum.reduce(spec, %{}, fn {k, v}, acc ->
          case v do
            {:uniform, a, b} -> Map.put(acc, k, a + :rand.uniform() * (b - a))
            {:log_uniform, a, b} ->
              la = :math.log(a); lb = :math.log(b)
              Map.put(acc, k, :math.exp(la + :rand.uniform() * (lb - la)))
            {:int, a, b} -> Map.put(acc, k, :rand.uniform() * (b - a) + a |> round)
            {:choice, choices} -> Map.put(acc, k, Enum.random(choices))
            other -> Map.put(acc, k, other)
          end
        end)

      {params, state}
    else
      spec = space_fun.(ix)
      numeric_keys =
        spec
        |> Enum.filter(fn {_k, v} -> match?({:uniform, _, _}, v) or match?({:log_uniform, _, _}, v) or match?({:int, _, _}, v) end)
        |> Enum.map(&elem(&1, 0))

      obs = for t <- history, is_number(t.score), do: {t.params, t.score}
      n_obs = max(length(obs), 1)
      gamma = min(0.25, :math.sqrt(n_obs) / n_obs)
      n_good = max(trunc(gamma * n_obs), 1)

      sorted =
        case state.goal do
          :minimize -> Enum.sort_by(obs, fn {_p, s} -> s end, :asc)
          _ -> Enum.sort_by(obs, fn {_p, s} -> s end, :desc)
        end

      {good, bad} = Enum.split(sorted, n_good)

      dists =
        Map.new(numeric_keys, fn k ->
          {k, build_kdes(k, good, bad, spec[k], state)}
        end)

      # Candidates from good KDE plus a few randoms to avoid mode collapse
      candidates =
        for _ <- 1..state.n_candidates do
          Enum.reduce(numeric_keys, %{}, fn k, acc ->
            case spec[k] do
              {:uniform, a, b} ->
                %{good: g} = dists[k]
                x = sample_kde(g)
                Map.put(acc, k, clamp(x, a, b))

              {:log_uniform, a, b} ->
                %{good: g} = dists[k]
                lx = sample_kde(g)
                lx = clamp(lx, :math.log(a), :math.log(b))
                Map.put(acc, k, :math.exp(lx))

              {:int, a, b} ->
                %{good: g} = dists[k]
                x = sample_kde(g)
                Map.put(acc, k, clamp(round(x), a, b))

              _ -> acc
            end
          end)
        end
        |> maybe_add_random(spec, numeric_keys, round(state.n_candidates * 0.1))

      choice_params =
        Enum.reduce(spec, %{}, fn
          {k, {:choice, choices}}, acc -> Map.put(acc, k, Enum.random(choices))
          _, acc -> acc
        end)

      scored =
        Enum.map(candidates, fn cand ->
          score = ei_score(cand, numeric_keys, dists, spec)
          {Map.merge(choice_params, cand), score}
        end)

      {best_cand, _} = Enum.max_by(scored, fn {_, s} -> s end)
      {best_cand, state}
    end
  end

  defp build_kdes(k, good, bad, spec, state) do
    transform = transform_fn(spec)
    gvals =
      good
      |> Enum.map(fn {p, _} -> p[k] end)
      |> Enum.filter(&is_number/1)
      |> Enum.map(transform)

    bvals =
      bad
      |> Enum.map(fn {p, _} -> p[k] end)
      |> Enum.filter(&is_number/1)
      |> Enum.map(transform)

    range = infer_range(spec, gvals ++ bvals)
    %{range: range, good: kde(gvals, range, state), bad: kde(bvals, range, state)}
  end

  defp kde([], {a, b}, state) do
    center = 0.5 * (a + b)
    sigma = max((b - a) * 0.1, state.bw_floor)
    %{xs: [center], sigmas: [sigma], width: max(b - a, 1.0e-12)}
  end

  defp kde(xs, {a, b}, state) do
    n = length(xs)
    mean = Enum.sum(xs) / n
    var = Enum.reduce(xs, 0.0, fn x, acc -> acc + :math.pow(x - mean, 2) end) / max(n - 1, 1)
    std = :math.sqrt(max(var, 1.0e-12))
    sigma = 0.5 * 1.06 * std * :math.pow(n, -0.2)
    sigma = max(sigma, (b - a) * state.bw_floor)
    %{xs: xs, sigmas: Enum.map(xs, fn _ -> sigma end), width: max(b - a, 1.0e-12)}
  end

  defp sample_kde(%{xs: xs, sigmas: sigmas}) do
    i = :rand.uniform(length(xs)) - 1
    mu = Enum.at(xs, i)
    si = Enum.at(sigmas, i)
    :rand.normal() * si + mu
  end

  defp ei_score(cand, ks, dists, spec) do
    Enum.reduce(ks, 0.0, fn k, acc ->
      %{good: g, bad: b} = dists[k]
      x =
        case spec[k] do
          {:log_uniform, _, _} -> :math.log(Map.fetch!(cand, k))
          _ -> Map.fetch!(cand, k)
        end

      pg = pdf(g, x) |> max(1.0e-12)
      pb = pdf(b, x) |> max(1.0e-12)
      acc + :math.log(pg / pb)
    end)
  end

  defp pdf(%{xs: xs, sigmas: sigmas, width: width}, x) do
    m = length(xs)
    base =
      if m == 0 do
        1.0e-9
      else
        Enum.zip(xs, sigmas)
        |> Enum.map(fn {mu, si} ->
          (1.0 / (si * :math.sqrt(2.0 * :math.pi()))) * :math.exp(-0.5 * :math.pow((x - mu) / si, 2))
        end)
        |> Enum.sum()
        |> Kernel./(m)
      end

    prior = 1.0 / width
    0.99 * base + 0.01 * prior
  end

  defp infer_range({:uniform, a, b}, _xs) do
    {a, b}
  end

  defp infer_range({:log_uniform, a, b}, _xs) do
    la = :math.log(a); lb = :math.log(b)
    {la, lb}
  end

  defp infer_range({:int, a, b}, _xs) do
    {a, b}
  end

  defp clamp(x, a, _b) when x < a, do: a
  defp clamp(x, _a, b) when x > b, do: b
  defp clamp(x, _a, _b), do: x

  defp maybe_add_random(candidates, _spec, _numeric_keys, extra) when extra <= 0, do: candidates
  defp maybe_add_random(candidates, spec, numeric_keys, extra) do
    randoms =
      for _ <- 1..extra do
        Enum.reduce(numeric_keys, %{}, fn k, acc ->
          case spec[k] do
            {:uniform, a, b} -> Map.put(acc, k, a + :rand.uniform() * (b - a))
            {:log_uniform, a, b} ->
              la = :math.log(a); lb = :math.log(b)
              Map.put(acc, k, :math.exp(la + :rand.uniform() * (lb - la)))
            {:int, a, b} -> Map.put(acc, k, :rand.uniform() * (b - a) + a |> round)
            _ -> acc
          end
        end)
      end

    candidates ++ randoms
  end

  defp transform_fn({:log_uniform, _, _}), do: &:math.log/1
  defp transform_fn(_), do: & &1
end
