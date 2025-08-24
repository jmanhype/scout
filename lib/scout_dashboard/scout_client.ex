
defmodule ScoutDashboard.ScoutClient do
  @moduledoc """
  Thin wrapper so the dashboard can run without Scout installed.
  If `Scout.Status` exists, we call it. Otherwise, we serve synthetic data.
  """

  @status_mod Application.compile_env(:scout_dashboard, :status_module, Scout.Status)

  def status(study_id) do
    if Code.ensure_loaded?(@status_mod) and function_exported?(@status_mod, :status, 1) do
      case apply(@status_mod, :status, [study_id]) do
        {:ok, status} -> status
        {:error, _} -> synthetic_status(study_id)
      end
    else
      synthetic_status(study_id)
    end
  end

  def best(study_id) do
    if Code.ensure_loaded?(@status_mod) and function_exported?(@status_mod, :best, 1) do
      apply(@status_mod, :best, [study_id])
    else
      %{study_id: study_id, trial_id: :rand.uniform(9999), score: :rand.uniform()}
    end
  end

  defp synthetic_status(_study_id) do
    rstats = fn ->
      obs = :rand.uniform(15) + 5
      pruned = :rand.uniform(trunc(obs * 0.5))
      completed = :rand.uniform(max(1, obs - pruned))
      running = max(0, obs - pruned - completed)
      %{observed: obs, pruned: pruned, completed: completed, running: running}
    end

    %{
      brackets: %{
        0 => %{0 => rstats.(), 1 => rstats.(), 2 => rstats.()},
        1 => %{0 => rstats.(), 1 => rstats.(), 2 => rstats.()},
        2 => %{0 => rstats.(), 1 => rstats.(), 2 => rstats.()}
      },
      totals: %{trials: 42, running: 7, pruned: 11, completed: 24}
    }
  end
end
