defmodule Scout.Playback do
  @moduledoc """
  Analyzes and replays Scout optimization runs from recorded NDJSON.
  
  Enables:
  - Extracting seeds for deterministic reproduction
  - Analyzing trial sequences and convergence
  - Comparing different runs
  - Debugging optimization issues
  
  ## Usage
  
      # Load a recording
      events = Scout.Playback.load("/tmp/run.ndjson")
      
      # Extract seeds used
      seeds = Scout.Playback.extract_seeds(events)
      
      # Get best trial trajectory
      trajectory = Scout.Playback.best_score_trajectory(events)
      
      # Replay with same seeds
      Scout.Playback.replay_study(events, my_objective)
  """
  
  require Logger
  
  @doc """
  Load events from an NDJSON recording file.
  """
  def load(path) do
    path
    |> File.stream!()
    |> Stream.map(&Jason.decode!/1)
    |> Enum.to_list()
  end
  
  @doc """
  Extract all RNG seeds used in a recording.
  
  Returns a map of trial_id => seed.
  """
  def extract_seeds(events) do
    events
    |> Enum.filter(fn e -> e["event"] == "scout.trial.started" end)
    |> Enum.reduce(%{}, fn event, acc ->
      trial_id = get_in(event, ["metadata", "trial_id"])
      seed = get_in(event, ["metadata", "seed"])
      
      if trial_id && seed do
        Map.put(acc, trial_id, seed)
      else
        acc
      end
    end)
  end
  
  @doc """
  Extract the best score trajectory over time.
  
  Returns a list of {trial_number, best_score_so_far} tuples.
  """
  def best_score_trajectory(events, goal \\ :minimize) do
    events
    |> Enum.filter(fn e -> e["event"] == "scout.trial.completed" end)
    |> Enum.filter(fn e -> get_in(e, ["metadata", "status"]) == "completed" end)
    |> Enum.sort_by(fn e -> e["timestamp"] end)
    |> Enum.reduce({nil, []}, fn event, {best, trajectory} ->
      score = get_in(event, ["measurements", "score"])
      trial_num = length(trajectory)
      
      new_best = case {best, goal} do
        {nil, _} -> score
        {b, :minimize} when score < b -> score
        {b, :maximize} when score > b -> score
        {b, _} -> b
      end
      
      {new_best, trajectory ++ [{trial_num, new_best}]}
    end)
    |> elem(1)
  end
  
  @doc """
  Extract parameters and scores for all completed trials.
  """
  def extract_trials(events) do
    # Build a map of trial_id => trial_data
    trials = %{}
    
    # First pass: collect trial starts
    trials = events
    |> Enum.filter(fn e -> e["event"] == "scout.trial.started" end)
    |> Enum.reduce(trials, fn event, acc ->
      trial_id = get_in(event, ["metadata", "trial_id"])
      params = get_in(event, ["metadata", "params"])
      
      Map.put(acc, trial_id, %{
        id: trial_id,
        params: params,
        started_at: event["timestamp"]
      })
    end)
    
    # Second pass: add completions
    events
    |> Enum.filter(fn e -> e["event"] == "scout.trial.completed" end)
    |> Enum.reduce(trials, fn event, acc ->
      trial_id = get_in(event, ["metadata", "trial_id"])
      
      if Map.has_key?(acc, trial_id) do
        Map.update!(acc, trial_id, fn trial ->
          Map.merge(trial, %{
            score: get_in(event, ["measurements", "score"]),
            status: get_in(event, ["metadata", "status"]),
            duration_us: get_in(event, ["measurements", "duration_us"]),
            finished_at: event["timestamp"]
          })
        end)
      else
        acc
      end
    end)
    |> Map.values()
    |> Enum.sort_by(& &1.started_at)
  end
  
  @doc """
  Replay a study with the same parameters and seeds.
  
  Requires an objective function to re-run trials.
  """
  def replay_study(events, objective_fn, opts \\ []) do
    study_id = extract_study_id(events) || "replay-#{System.unique_integer([:positive])}"
    
    trials = extract_trials(events)
    seeds = extract_seeds(events)
    
    Logger.info("Replaying #{length(trials)} trials from recording")
    
    results = Enum.map(trials, fn trial ->
      # Set RNG seed if available
      if seed = seeds[trial.id] do
        :rand.seed(:exsss, {seed, seed, seed})
      end
      
      # Re-run objective
      start = System.monotonic_time(:microsecond)
      
      result = try do
        case objective_fn.(trial.params) do
          {:ok, score} -> {:ok, score}
          score when is_number(score) -> {:ok, score}
          error -> {:error, error}
        end
      rescue
        e -> {:error, Exception.message(e)}
      end
      
      duration = System.monotonic_time(:microsecond) - start
      
      %{
        id: trial.id,
        params: trial.params,
        original_score: trial[:score],
        replay_score: elem(result, 1),
        duration_us: duration,
        match?: trial[:score] == elem(result, 1)
      }
    end)
    
    # Summary statistics
    matches = Enum.count(results, & &1.match?)
    total = length(results)
    
    Logger.info("Replay complete: #{matches}/#{total} trials matched original scores")
    
    %{
      study_id: study_id,
      trials: results,
      reproducibility: matches / total * 100,
      summary: %{
        total_trials: total,
        matching_scores: matches,
        mismatched_scores: total - matches
      }
    }
  end
  
  @doc """
  Generate a summary report from a recording.
  """
  def summary(events) do
    trials = extract_trials(events)
    completed = Enum.filter(trials, fn t -> t[:status] == "completed" end)
    
    %{
      total_events: length(events),
      total_trials: length(trials),
      completed_trials: length(completed),
      failed_trials: length(trials) - length(completed),
      best_score: best_score_from_trials(completed),
      avg_duration_ms: average_duration(completed),
      total_duration_ms: total_duration(events)
    }
  end
  
  # Helpers
  
  defp extract_study_id(events) do
    events
    |> Enum.find(fn e -> e["event"] == "scout.study.created" end)
    |> get_in(["metadata", "study_id"])
  end
  
  defp best_score_from_trials(trials) do
    trials
    |> Enum.map(& &1.score)
    |> Enum.filter(& &1)
    |> case do
      [] -> nil
      scores -> Enum.min(scores)
    end
  end
  
  defp average_duration(trials) do
    durations = trials
    |> Enum.map(& &1[:duration_us])
    |> Enum.filter(& &1)
    
    if Enum.empty?(durations) do
      0
    else
      Enum.sum(durations) / length(durations) / 1000
    end
  end
  
  defp total_duration(events) do
    case {List.first(events), List.last(events)} do
      {%{"timestamp" => start}, %{"timestamp" => finish}} ->
        finish - start
      _ ->
        0
    end
  end
end