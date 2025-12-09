#!/usr/bin/env python3
"""
Compare Optuna TPE vs Scout TPE on simple benchmarks.
Runs inside the venv created at .venv/. Requires optuna installed there.
"""

import json, subprocess, sys, math, random, tempfile, os

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, ".."))
PYTHON = os.path.join(REPO, ".venv", "bin", "python")

def run_optuna(n_trials, seed, space):
    code = f"""
import optuna, math, random, json
random.seed({seed})
def objective(trial):
    x = trial.suggest_float('x', {space['x'][0]}, {space['x'][1]})
    y = trial.suggest_float('y', {space['y'][0]}, {space['y'][1]})
    return x*x + y*y
study = optuna.create_study(direction='minimize', sampler=optuna.samplers.TPESampler(seed={seed}))
study.optimize(objective, n_trials={n_trials})
print(json.dumps({{'best_value': study.best_value, 'best_params': study.best_params}}))
"""
    out = subprocess.check_output([PYTHON, "-c", code], text=True)
    return json.loads(out.strip())

def run_scout(n_trials, seed, space):
    tmpl = """
Application.put_env(:scout_core, :store_adapter, Scout.Store.ETS)
case Process.whereis(Scout.Store.ETS) do
  nil -> {:ok, _} = Scout.Store.ETS.start_link([])
  _ -> :ok
end
space_fun = fn _ix -> %{x: {:uniform, XMIN, XMAX}, y: {:uniform, YMIN, YMAX}} end
study = %Scout.Study{id: "parity_#{System.unique_integer([:positive])}",
           goal: :minimize,
           max_trials: NTRIALS,
           parallelism: 1,
           search_space: space_fun,
           objective: fn p -> p.x * p.x + p.y * p.y end,
           sampler: Scout.Sampler.TPEOptuna,
           sampler_opts: %{min_obs: 10, n_candidates: 64},
           seed: SEED}
{:ok, result} = Scout.Executor.Iterative.run(study)
IO.puts(Jason.encode!(%{best_score: result.best_score, best_params: result.best_params}))
"""
    elixir = (
        tmpl.replace("XMIN", str(space["x"][0]))
            .replace("XMAX", str(space["x"][1]))
            .replace("YMIN", str(space["y"][0]))
            .replace("YMAX", str(space["y"][1]))
            .replace("NTRIALS", str(n_trials))
            .replace("SEED", str(seed))
    )
    out = subprocess.check_output(["mix", "run", "-e", elixir], text=True, cwd=REPO)
    # mix prints warnings/noise; take the last non-empty line as the JSON payload
    payload = [line for line in out.splitlines() if line.strip()][-1]
    return json.loads(payload)

def main():
    bench = "sphere"
    space = {"x": (-5.0, 5.0), "y": (-5.0, 5.0)}
    n_trials = 200
    seed = 123

    print(f"Benchmark: {bench}, trials={n_trials}, seed={seed}")
    o = run_optuna(n_trials, seed, space)
    s = run_scout(n_trials, seed, space)

    print("\\nOptuna TPE:")
    print(json.dumps(o, indent=2))

    print("\\nScout TPE:")
    print(json.dumps(s, indent=2))

    obest = o["best_value"]
    sbest = s["best_score"]
    better = "Optuna" if obest < sbest else ("Scout" if sbest < obest else "Tie")
    print(f"\\nWinner on {bench}: {better} (Optuna {obest:.6f} vs Scout {sbest:.6f})")

if __name__ == "__main__":
    sys.exit(main())
