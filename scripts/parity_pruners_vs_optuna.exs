#!/usr/bin/env python3
"""
Compare prune decisions between Optuna and Scout pruners on synthetic learning curves.
Checks Median, Percentile, Hyperband/SHA, Wilcoxon.
"""
import json, subprocess, os, sys, random

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, ".."))
PYTHON = os.path.join(REPO, ".venv", "bin", "python")

CURVE = [1.0 / (e+1) for e in range(10)]  # decaying loss

def optuna_pruner(pruner_ctor, seed):
    code = f"""
import optuna, random, json
random.seed({seed})
study = optuna.create_study(direction='minimize', pruner={pruner_ctor})
trial = study.ask()
for step, val in enumerate({CURVE}):
    trial.report(val, step)
    if trial.should_prune():
        raise optuna.TrialPruned()
trial.set_user_attr("done", True)
print(json.dumps({{'pruned': False}}))
"""
    try:
        subprocess.check_output([PYTHON, "-c", code], text=True, stderr=subprocess.STDOUT)
        return {"pruned": False}
    except subprocess.CalledProcessError as e:
        if "TrialPruned" in e.output:
            return {"pruned": True}
        raise

def scout_pruner(pruner_mod, seed):
    tmpl = """
Application.put_env(:scout_core, :store_adapter, Scout.Store.ETS)
case Process.whereis(Scout.Store.ETS) do
  nil -> {:ok, _} = Scout.Store.ETS.start_link([])
  _ -> :ok
end
curve = CURVE
study = %Scout.Study{id: "prune_#{System.unique_integer([:positive])}",
           goal: :minimize,
           max_trials: 1,
           parallelism: 1,
           search_space: %{x: {:uniform, 0.0, 1.0}},
           objective: fn _, report ->
             Enum.reduce_while(Enum.with_index(curve), 0.0, fn {v, step}, _ ->
               case report.(v, step) do
                 :continue -> {:cont, v}
                 :prune -> {:halt, {:pruned, v}}
               end
             end)
           end,
           pruner: PRUNER,
           pruner_opts: %{},
           sampler: Scout.Sampler.RandomSearch,
           sampler_opts: %{},
           seed: SEED}
{:ok, result} = Scout.Executor.Iterative.run(study)
pruned = case result.trials do
  [%{status: :pruned} | _] -> true
  _ -> false
end
IO.puts(Jason.encode!(%{pruned: pruned}))
"""
    elixir = (
        tmpl.replace("CURVE", inspect(CURVE))
            .replace("PRUNER", pruner_mod)
            .replace("SEED", str(seed))
    )
    out = subprocess.check_output(["mix", "run", "-e", elixir], text=True, cwd=REPO)
    payload = [line for line in out.splitlines() if line.strip()][-1]
    return json.loads(payload)

def compare(pruner_ctor, pruner_mod, seed):
    o = optuna_pruner(pruner_ctor, seed)
    s = scout_pruner(pruner_mod, seed)
    match = o["pruned"] == s["pruned"]
    print(f"{pruner_mod.split('.')[-1]:20s} Optuna={o['pruned']} Scout={s['pruned']} match={match}")

def main():
    seed = 123
    compare("optuna.pruners.MedianPruner()", "Scout.Pruner.MedianPruner", seed)
    compare("optuna.pruners.PercentilePruner(25.0)", "Scout.Pruner.PercentilePruner", seed)
    compare("optuna.pruners.SuccessiveHalvingPruner()", "Scout.Pruner.SuccessiveHalving", seed)
    compare("optuna.pruners.HyperbandPruner()", "Scout.Pruner.Hyperband", seed)
    compare("optuna.pruners.WilcoxonPruner()", "Scout.Pruner.WilcoxonPruner", seed)

if __name__ == "__main__":
    sys.exit(main())
