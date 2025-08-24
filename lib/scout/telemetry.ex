defmodule Scout.Telemetry do
  @moduledoc """
  Telemetry event definitions and helpers for Scout.
  
  ## Events
  
  ### Study Events
  
  * `[:scout, :study, :start]`
    - Measurements: `%{trials: non_neg_integer()}`
    - Metadata: `%{study: binary(), executor: atom()}`
  
  * `[:scout, :study, :stop]`
    - Measurements: `%{completed: non_neg_integer(), duration: non_neg_integer()}`
    - Metadata: `%{study: binary(), best: map() | nil}`
  
  ### Trial Events
  
  * `[:scout, :trial, :start]`
    - Measurements: `%{ix: non_neg_integer()}`
    - Metadata: `%{study: binary(), trial_id: binary(), bracket: non_neg_integer(), params: map()}`
  
  * `[:scout, :trial, :stop]`
    - Measurements: `%{duration: non_neg_integer()}`
    - Metadata: `%{study: binary(), trial_id: binary(), score: number(), status: atom()}`
  
  * `[:scout, :trial, :prune]`
    - Measurements: `%{rung: non_neg_integer()}`
    - Metadata: `%{study: binary(), trial_id: binary(), reason: atom()}`
  """
  
  # Event name constants
  @study_start [:scout, :study, :start]
  @study_stop  [:scout, :study, :stop]
  @trial_start [:scout, :trial, :start]
  @trial_stop  [:scout, :trial, :stop]
  @trial_prune [:scout, :trial, :prune]
  
  @doc """
  Emits a study start event.
  
  ## Parameters
    - measurements: Map with `:trials` key (number of trials to run)
    - metadata: Map with `:study` (study ID) and `:executor` (executor module)
  """
  def study_start(measurements, metadata) do
    execute_safe(@study_start, measurements, metadata)
  end
  
  @doc """
  Emits a study stop event.
  
  ## Parameters
    - measurements: Map with `:completed` (trials completed) and optional `:duration`
    - metadata: Map with `:study` (study ID) and optional `:best` (best result)
  """
  def study_stop(measurements, metadata) do
    execute_safe(@study_stop, measurements, metadata)
  end
  
  @doc """
  Emits a trial start event.
  
  ## Parameters
    - measurements: Map with `:ix` (trial index)
    - metadata: Map with `:study`, `:trial_id`, `:bracket`, and `:params`
  """
  def trial_start(measurements, metadata) do
    execute_safe(@trial_start, measurements, metadata)
  end
  
  @doc """
  Emits a trial stop event.
  
  ## Parameters
    - measurements: Map with optional `:duration`
    - metadata: Map with `:study`, `:trial_id`, `:score`, and `:status`
  """
  def trial_stop(measurements, metadata) do
    execute_safe(@trial_stop, measurements, metadata)
  end
  
  @doc """
  Emits a trial prune event.
  
  ## Parameters
    - measurements: Map with `:rung` (pruning rung)
    - metadata: Map with `:study`, `:trial_id`, and optional `:reason`
  """
  def trial_prune(measurements, metadata) do
    execute_safe(@trial_prune, measurements, metadata)
  end
  
  # Legacy compatibility functions
  @doc false
  def study_event(:start, meas, meta), do: study_start(meas, meta)
  @doc false
  def study_event(:stop, meas, meta), do: study_stop(meas, meta)
  @doc false
  def trial_event(:start, meas, meta), do: trial_start(meas, meta)
  @doc false
  def trial_event(:stop, meas, meta), do: trial_stop(meas, meta)
  @doc false
  def trial_event(:prune, meas, meta), do: trial_prune(meas, meta)
  
  # Private helper to safely execute telemetry events
  defp execute_safe(event_name, measurements, metadata) do
    # Ensure measurements and metadata are maps
    meas = ensure_map(measurements)
    meta = ensure_map(metadata)
    
    # Try to use telemetry if available, otherwise silently skip
    try do
      :telemetry.execute(event_name, meas, meta)
    rescue
      UndefinedFunctionError -> :ok
    end
  end
  
  defp ensure_map(val) when is_map(val), do: val
  defp ensure_map(_), do: %{}
end