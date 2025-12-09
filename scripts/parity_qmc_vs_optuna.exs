#!/usr/bin/env python3
"""
Compare QMC sequences (Halton, Sobol) between Scout and Optuna (scipy.stats.qmc).
Checks first N points with fixed seeds/scramble settings.
"""
import os, sys, json, subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, ".."))
PYTHON = os.path.join(REPO, ".venv", "bin", "python")

def run_optuna_qmc(kind, n, dims, seed):
    scramble = "True" if kind=="sobol" else "False"
    code = f"""
import json
from scipy.stats import qmc
sampler = qmc.{ 'Sobol' if kind=='sobol' else 'Halton' }(d={dims}, scramble={scramble}, seed={seed})
pts = sampler.random({n})
print(json.dumps(pts.tolist()))
"""
    out = subprocess.check_output([PYTHON, "-c", code], text=True)
    return json.loads(out.strip())

def run_scout_qmc(kind, n, dims, seed):
    tmpl = """
Application.put_env(:scout_core, :store_adapter, Scout.Store.ETS)
case Process.whereis(Scout.Store.ETS) do
  nil -> {:ok, _} = Scout.Store.ETS.start_link([])
  _ -> :ok
end
points = Scout.Sampler.QMC.sample(:KIND, NPTS, DIMS, seed: SEED)
IO.puts(Jason.encode!(points))
"""
    elixir = (
        tmpl.replace("KIND", kind)
            .replace("NPTS", str(n))
            .replace("DIMS", str(dims))
            .replace("SEED", str(seed))
    )
    out = subprocess.check_output(["mix", "run", "-e", elixir], text=True, cwd=REPO)
    payload = [line for line in out.splitlines() if line.strip()][-1]
    return json.loads(payload)

def compare(kind, n, dims, seed):
    o = run_optuna_qmc(kind, n, dims, seed)
    s = run_scout_qmc(kind, n, dims, seed)
    max_diff = 0.0
    for i in range(n):
        for d in range(dims):
            max_diff = max(max_diff, abs(o[i][d] - s[i][d]))
    print(f"{kind.upper()} dims={dims} n={n} seed={seed} max_diff={max_diff:.6e}")

def main():
    for kind in ["halton", "sobol"]:
        compare(kind, n=16, dims=2, seed=123)
        compare(kind, n=16, dims=4, seed=456)

if __name__ == "__main__":
    sys.exit(main())
