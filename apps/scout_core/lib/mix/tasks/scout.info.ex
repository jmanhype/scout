defmodule Mix.Tasks.Scout.Info do
  @moduledoc """
  Show Scout configuration and running studies.

  ## Usage

      mix scout.info

  Displays:
  - Storage mode (Postgres vs ETS)
  - Running studies
  - System status
  """
  @shortdoc "Show Scout configuration and running studies"

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    # Start the application
    Mix.Task.run("app.start")

    IO.puts("\n=== Scout System Info ===\n")

    # Storage mode
    storage_mode = Scout.Store.storage_mode()
    storage_icon = if storage_mode == :postgres, do: "💾", else: "⚡"
    IO.puts("#{storage_icon} Storage: #{storage_mode} (#{if storage_mode == :postgres, do: "persistent", else: "ephemeral"})")

    # Health check
    case Scout.Store.health_check() do
      :ok -> IO.puts("✅ Store: healthy")
      {:error, reason} -> IO.puts("❌ Store: #{inspect(reason)}")
    end

    # List studies
    studies = Scout.Store.list_studies()
    IO.puts("\n📚 Studies: #{length(studies)}")

    if length(studies) > 0 do
      IO.puts("\nID                          | Status     | Trials | Best Score")
      IO.puts("---------------------------|-----------|---------|-----------")

      for study <- studies do
        trials = Scout.Store.list_trials(study.id)
        best_trial = Enum.min_by(trials, & &1.score, fn -> nil end)
        best_score = if best_trial, do: Float.round(best_trial.score, 4), else: "N/A"

        IO.puts("#{String.pad_trailing(study.id, 27)} | #{String.pad_trailing(to_string(Map.get(study, :status, "unknown")), 9)} | #{String.pad_trailing(to_string(length(trials)), 7)} | #{best_score}")
      end
    end

    IO.puts("")
  end
end
