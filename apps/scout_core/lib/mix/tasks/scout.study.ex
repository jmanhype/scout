
defmodule Mix.Tasks.Scout.Study do
  use Mix.Task
  @shortdoc "Manage Scout studies"
  @moduledoc """
  Usage:
    mix scout.study start path/to/study.exs [--executor local|iterative|oban]
    mix scout.study status STUDY_ID
    mix scout.study pause  STUDY_ID
    mix scout.study resume STUDY_ID
    mix scout.study cancel STUDY_ID

  The study file must `return` a study map.
  For Oban/durable runs, consider defining `:module` pointing to a module with `search_space/1` and `objective/1|2`.
  """

  def run(["start", path | rest]) do
    {opts, _argv, _} = OptionParser.parse(rest, strict: [executor: :string])
    exec =
      case opts[:executor] do
        "oban" -> :oban
        "iterative" -> :iterative
        _ -> :local
      end

    {study, _} = Code.eval_file(path)
    study = Map.put(study, :executor, exec)
    IO.inspect(Scout.StudyRunner.run(study), label: "SCOUT")
  end

  def run(["status", study_id]) do
    case Scout.Store.get_study(study_id) do
      {:ok, meta} ->
        trials = Scout.Store.list_trials(study_id)
        IO.puts("Study #{study_id} status=#{meta[:status]} trials=#{length(trials)}")
        best = case meta[:goal] do
          :minimize -> Enum.min_by(trials, & &1.score, fn -> nil end)
          _ -> Enum.max_by(trials, & &1.score, fn -> nil end)
        end
        IO.puts("Best: " <> inspect(best && %{score: best.score, params: best.params}))
      _ -> IO.puts("No such study")
    end
  end

  def run(["pause", study_id]) do
    :ok = Scout.Store.set_study_status(study_id, "paused")
    IO.puts("Paused #{study_id}")
  end

  def run(["resume", study_id]) do
    :ok = Scout.Store.set_study_status(study_id, "running")
    IO.puts("Resumed #{study_id}")
  end

  def run(["cancel", study_id]) do
    :ok = Scout.Store.set_study_status(study_id, "cancelled")
    IO.puts("Cancelled #{study_id}. New jobs should check status and stop early.")
  end

  def run(_), do: IO.puts("Usage: mix scout.study start|status|pause|resume|cancel …")
end
