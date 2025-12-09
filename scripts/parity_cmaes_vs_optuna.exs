#!/usr/bin/env python3
"""
Compare Optuna CMA-ES vs Scout CMA-ES on simple benchmarks (sphere, rosenbrock).
Requires Optuna installed in .venv/. Uses mix run for Scout side.
"""
import json, subprocess, os, math, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, ".."))
PYTHON = os.path.join(REPO, ".venv", "bin", "python")

def run_optuna(obj, space, n_trials, seed, sampler="CmaEsSampler"):
    code = f"""
import optuna, math, json, random
random.seed({seed})
def objective(trial):
    x = trial.suggest_float('x', {space['x'][0]}, {space['x'][1]})
    y = trial.suggest_float('y', {space['y'][0]}, {space['y'][1]})
    if '{obj}' == 'sphere':
        return x*x + y*y
    else:
        return (1.0 - x)**2 + 100.0 * (y - x*x)**2
study = optuna.create_study(direction='minimize', sampler=getattr(optuna.samplers, sampler)(seed={seed}))
study.optimize(objective, n_trials={n_trials})
print(json.dumps({{'best_value': study.best_value, 'best_params': study.best_params}}))
"""
    out = subprocess.check_output([PYTHON, "-c", code], text=True)
    return json.loads(out.strip())

def run_scout(obj, space, n_trials, seed):
    tmpl = """
Application.put_env(:scout_core, :store_adapter, Scout.Store.ETS)
case Process.whereis(Scout.Store.ETS) do
  nil -> {:ok, _} = Scout.Store.ETS.start_link([])
  _ -> :ok
end
space_fun = fn _ix -> %{x: {:uniform, XMIN, XMAX}, y: {:uniform, YMIN, YMAX}} end
obj = fn p ->
  if OBJ == :sphere do
    p.x * p.x + p.y * p.y
  else
    (:math.pow(1.0 - p.x, 2)) + 100.0 * :math.pow(p.y - p.x * p.x, 2)
  end
end
study = %Scout.Study{id: "parity_cmaes_#{System.unique_integer([:positive])}",
           goal: :minimize,
           max_trials: NTRIALS,
           parallelism: 1,
           search_space: space_fun,
           objective: obj,
           sampler: Scout.Sampler.CmaEs,
           sampler_opts: %{min_obs: 3},
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
            .replace("OBJ", ":sphere" if obj=="sphere" else ":rosen")
    )
    out = subprocess.check_output(["mix", "run", "-e", elixir], text=True, cwd=REPO)
    payload = [line for line in out.splitlines() if line.strip()][-1]
    return json.loads(payload)

def bench(obj, seeds, n_trials, space):
    print(f"\nBenchmark: {obj}, trials={n_trials}, seeds={seeds}")
    for seed in seeds:
        o = run_optuna(obj, space, n_trials, seed, sampler="CmaEsSampler")
        s = run_scout(obj, space, n_trials, seed)
        obest, sbest = o["best_value"], s["best_score"]
        better = "Optuna" if obest < sbest else ("Scout" if sbest < obest else "Tie")
        print(f"Seed {seed}: Optuna {obest:.6f} vs Scout {sbest:.6f} -> {better}")

def main():
    seeds = [123, 456, 789]
    bench("sphere", seeds, 200, {"x": (-5.0, 5.0), "y": (-5.0, 5.0)})
    bench("rosen", seeds, 200, {"x": (-2.0, 2.0), "y": (-2.0, 2.0)})

if __name__ == "__main__":
    sys.exit(main())
