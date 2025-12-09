alias Scout.Executor.{Local, Iterative}
alias Scout.Store

# Ensure ETS adapter is running
Application.put_env(:scout_core, :store_adapter, Scout.Store.ETS)
case Process.whereis(Scout.Store.ETS) do
  nil -> {:ok, _} = Scout.Store.ETS.start_link([])
  _ -> :ok
end

samplers = [
  Scout.Sampler.Random,
  Scout.Sampler.RandomSearch,
  Scout.Sampler.Grid,
  Scout.Sampler.Bandit,
  Scout.Sampler.GP,
  Scout.Sampler.CmaEs,
  Scout.Sampler.CmaesSimple,
  Scout.Sampler.NSGA2,
  Scout.Sampler.TPE,
  Scout.Sampler.TPEFixed,
  Scout.Sampler.TPEEnhanced,
  Scout.Sampler.TPEIntegrated,
  Scout.Sampler.TPEMultivariate,
  Scout.Sampler.MultivarTPE,
  Scout.Sampler.MultivariateTpe,
  Scout.Sampler.MultivariateTpeV2,
  Scout.Sampler.ConditionalTPE,
  Scout.Sampler.ConstantLiarTPE,
  Scout.Sampler.CorrelatedTpe,
  Scout.Sampler.OptimizedCorrelatedTpe,
  Scout.Sampler.PriorTPE,
  Scout.Sampler.WarmStartTPE,
  Scout.Sampler.QMC,
  Scout.Sampler.MOTPE
]

pruners = [
  Scout.Pruner.SuccessiveHalving,
  Scout.Pruner.Hyperband,
  Scout.Pruner.MedianPruner,
  Scout.Pruner.PercentilePruner,
  Scout.Pruner.PatientPruner,
  Scout.Pruner.ThresholdPruner,
  Scout.Pruner.WilcoxonPruner
]

defmodule Smoke do
  def run_samplers(list) do
    Enum.map(list, fn mod ->
      result =
        try do
          space_fun = fn _ -> %{x: {:uniform, -3.0, 3.0}, y: {:uniform, -3.0, 3.0}} end
          state = mod.init(%{goal: :minimize})
          {params, _} =
            try do
              mod.next(%{x: {:uniform, -3.0, 3.0}, y: {:uniform, -3.0, 3.0}}, 0, [], state)
            rescue
              _ -> mod.next(space_fun, 0, [], state)
            end
          {:ok, params}
        rescue
          e -> {:error, {e, __STACKTRACE__}}
        catch
          kind, reason -> {:error, {kind, reason}}
        end

      {mod, result}
    end)
  end

  def run_pruners(list) do
    Enum.map(list, fn mod ->
      id =
        ("smoke_pruner_" <> to_string(mod))
        |> String.replace(~r/[^A-Za-z0-9]/, "_")

      study = %{
        id: id,
        goal: :minimize,
        max_trials: 4,
        parallelism: 1,
        search_space: %{x: {:uniform, -2.0, 2.0}},
        objective: fn params, report ->
          score = params.x * params.x
          # Simulate a few rungs
          _ = report.(score, 0)
          _ = report.(score * 0.8, 1)
          score
        end,
        pruner: mod,
        pruner_opts: %{},
        sampler: Scout.Sampler.RandomSearch,
        sampler_opts: %{},
        seed: 99
      }

      result =
        try do
          case Iterative.run(study) do
            {:ok, %{best_score: score}} -> {:ok, Float.round(score, 6)}
            {:ok, map} -> {:ok, map}
            other -> {:error, other}
          end
        rescue
          e -> {:error, {e, __STACKTRACE__}}
        catch
          kind, reason -> {:error, {kind, reason}}
        end

      {mod, result}
    end)
  end
end

sampler_results = Smoke.run_samplers(samplers)
pruner_results = Smoke.run_pruners(pruners)

print = fn label, results ->
  IO.puts("\n" <> label)
  IO.puts(String.duplicate("-", String.length(label)))
  Enum.each(results, fn {mod, res} ->
    case res do
      {:ok, val} -> IO.puts("✅ #{inspect(mod)} -> #{inspect(val)}")
      {:error, reason} -> IO.puts("❌ #{inspect(mod)} -> #{inspect(reason)}")
    end
  end)
end

print.("Sampler Smoke Results", sampler_results)
print.("Pruner Smoke Results", pruner_results)
