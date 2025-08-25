defmodule Scout.TelemetryEnhanced do
  @moduledoc """
  Enhanced telemetry with structured error handling and comprehensive event coverage.
  
  FIXES from original Scout.Telemetry:
  - Structured error categorization (no more silent failures)
  - Comprehensive event coverage (store, sampler, executor events)
  - Proper logging levels based on event severity
  - Error context preservation
  - Performance measurement integration
  
  Events follow the pattern: [:scout, :component, :action, :result]
  """

  require Logger

  # Event definitions - comprehensive coverage
  @trial_events [
    [:scout, :trial, :start],
    [:scout, :trial, :complete], 
    [:scout, :trial, :error],
    [:scout, :trial, :timeout],
    [:scout, :trial, :prune]
  ]

  @study_events [
    [:scout, :study, :start],
    [:scout, :study, :complete],
    [:scout, :study, :pause],
    [:scout, :study, :resume],
    [:scout, :study, :error]
  ]

  @sampler_events [
    [:scout, :sampler, :sample],
    [:scout, :sampler, :error],
    [:scout, :sampler, :fallback]
  ]

  @store_events [
    [:scout, :store, :read],
    [:scout, :store, :write],
    [:scout, :store, :error],
    [:scout, :store, :health_check]
  ]

  @executor_events [
    [:scout, :executor, :dispatch],
    [:scout, :executor, :complete],
    [:scout, :executor, :error],
    [:scout, :executor, :timeout]
  ]

  ## Enhanced Trial Events

  @doc "Trial execution started"
  def trial_start(measurements \\ %{}, metadata) do
    emit_event([:scout, :trial, :start], 
      ensure_measurements(measurements, %{count: 1}), metadata)
  end

  @doc "Trial completed successfully"  
  def trial_complete(measurements \\ %{}, metadata) do
    emit_event([:scout, :trial, :complete],
      ensure_measurements(measurements, %{count: 1}), metadata)
  end

  @doc "Trial failed with structured error"
  def trial_error(measurements \\ %{}, metadata) do
    enhanced_metadata = enhance_error_metadata(metadata)
    Logger.error("Trial error: #{format_error_context(enhanced_metadata)}")
    
    emit_event([:scout, :trial, :error],
      ensure_measurements(measurements, %{count: 1}), enhanced_metadata)
  end

  @doc "Trial timed out"
  def trial_timeout(measurements \\ %{}, metadata) do
    Logger.warn("Trial timeout: #{format_context(metadata)}")
    emit_event([:scout, :trial, :timeout],
      ensure_measurements(measurements, %{count: 1}), metadata)
  end

  @doc "Trial was pruned early"
  def trial_prune(measurements \\ %{}, metadata) do
    emit_event([:scout, :trial, :prune],
      ensure_measurements(measurements, %{count: 1}), metadata)
  end

  ## Enhanced Study Events

  @doc "Study execution started"
  def study_start(measurements \\ %{}, metadata) do
    Logger.info("Study started: #{format_context(metadata)}")
    emit_event([:scout, :study, :start],
      ensure_measurements(measurements, %{count: 1}), metadata)
  end

  @doc "Study completed successfully"
  def study_complete(measurements \\ %{}, metadata) do
    Logger.info("Study completed: #{format_context(metadata)}")
    emit_event([:scout, :study, :complete],
      ensure_measurements(measurements, %{count: 1}), metadata)
  end

  @doc "Study paused"
  def study_pause(measurements \\ %{}, metadata) do
    Logger.info("Study paused: #{format_context(metadata)}")
    emit_event([:scout, :study, :pause],
      ensure_measurements(measurements, %{count: 1}), metadata)
  end

  @doc "Study resumed"  
  def study_resume(measurements \\ %{}, metadata) do
    Logger.info("Study resumed: #{format_context(metadata)}")
    emit_event([:scout, :study, :resume],
      ensure_measurements(measurements, %{count: 1}), metadata)
  end

  @doc "Study error with structured handling"
  def study_error(measurements \\ %{}, metadata) do
    enhanced_metadata = enhance_error_metadata(metadata)
    Logger.error("Study error: #{format_error_context(enhanced_metadata)}")
    
    emit_event([:scout, :study, :error],
      ensure_measurements(measurements, %{count: 1}), enhanced_metadata)
  end

  ## New Sampler Events (missing from original)

  @doc "Sampler generated new parameters"
  def sampler_sample(measurements \\ %{}, metadata) do
    emit_event([:scout, :sampler, :sample],
      ensure_measurements(measurements, %{count: 1}), metadata)
  end

  @doc "Sampler error with categorization"
  def sampler_error(measurements \\ %{}, metadata) do
    enhanced_metadata = enhance_error_metadata(metadata)
    Logger.error("Sampler error: #{format_error_context(enhanced_metadata)}")
    
    emit_event([:scout, :sampler, :error],
      ensure_measurements(measurements, %{count: 1}), enhanced_metadata)
  end

  @doc "Sampler fell back to random sampling"
  def sampler_fallback(measurements \\ %{}, metadata) do
    Logger.warn("Sampler fallback: #{format_context(metadata)}")
    emit_event([:scout, :sampler, :fallback],
      ensure_measurements(measurements, %{count: 1}), metadata)
  end

  ## New Store Events (missing from original)

  @doc "Store read operation with timing"
  def store_read(measurements \\ %{}, metadata) do
    emit_event([:scout, :store, :read],
      ensure_measurements(measurements, %{count: 1}), metadata)
  end

  @doc "Store write operation with timing"
  def store_write(measurements \\ %{}, metadata) do
    emit_event([:scout, :store, :write],
      ensure_measurements(measurements, %{count: 1}), metadata)
  end

  @doc "Store operation error with details"
  def store_error(measurements \\ %{}, metadata) do
    enhanced_metadata = enhance_error_metadata(metadata)
    Logger.error("Store error: #{format_error_context(enhanced_metadata)}")
    
    emit_event([:scout, :store, :error],
      ensure_measurements(measurements, %{count: 1}), enhanced_metadata)
  end

  @doc "Store health check result"
  def store_health_check(measurements \\ %{}, metadata) do
    level = case Map.get(metadata, :result) do
      :ok -> :debug
      _ -> :warn
    end
    
    Logger.log(level, "Store health check: #{format_context(metadata)}")
    emit_event([:scout, :store, :health_check],
      ensure_measurements(measurements, %{count: 1}), metadata)
  end

  ## New Executor Events (missing from original)

  @doc "Executor dispatched work"
  def executor_dispatch(measurements \\ %{}, metadata) do
    emit_event([:scout, :executor, :dispatch],
      ensure_measurements(measurements, %{count: 1}), metadata)
  end

  @doc "Executor completed work"
  def executor_complete(measurements \\ %{}, metadata) do
    emit_event([:scout, :executor, :complete],
      ensure_measurements(measurements, %{count: 1}), metadata)
  end

  @doc "Executor error with context"
  def executor_error(measurements \\ %{}, metadata) do
    enhanced_metadata = enhance_error_metadata(metadata)
    Logger.error("Executor error: #{format_error_context(enhanced_metadata)}")
    
    emit_event([:scout, :executor, :error],
      ensure_measurements(measurements, %{count: 1}), enhanced_metadata)
  end

  @doc "Executor operation timeout"
  def executor_timeout(measurements \\ %{}, metadata) do
    Logger.warn("Executor timeout: #{format_context(metadata)}")
    emit_event([:scout, :executor, :timeout],
      ensure_measurements(measurements, %{count: 1}), metadata)
  end

  ## Structured Error Handling Utilities

  @doc """
  Execute function with telemetry wrapper and structured error handling.
  
  Automatically emits start/complete/error events with timing.
  Returns {:ok, result} | {:error, {category, reason, context}}
  """
  def with_telemetry(event_prefix, metadata, fun) when is_function(fun, 0) do
    start_time = System.monotonic_time()
    
    # Emit start event
    emit_event(event_prefix ++ [:start], %{count: 1}, metadata)
    
    try do
      result = fun.()
      duration = System.monotonic_time() - start_time
      
      # Emit success event
      emit_event(event_prefix ++ [:complete], %{duration: duration}, metadata)
      {:ok, result}
    rescue
      error ->
        duration = System.monotonic_time() - start_time
        
        # Categorize and structure the error
        {category, reason} = categorize_error(error)
        error_context = Map.merge(metadata, %{
          duration: duration,
          error_category: category,
          error_reason: reason,
          error_details: Exception.message(error),
          stacktrace: Exception.format_stacktrace(__STACKTRACE__)
        })
        
        # Emit error event with context
        emit_event(event_prefix ++ [:error], %{duration: duration}, error_context)
        
        {:error, {category, reason, error_context}}
    end
  end

  @doc """
  Structure error with categorization for consistent handling.
  
  Categories help with error aggregation and alerting:
  - :validation - Bad input, configuration errors
  - :timeout - Operation timeouts 
  - :database - Database/persistence errors
  - :network - Network connectivity issues
  - :arithmetic - Mathematical errors (NaN, division by zero)
  - :resource - Memory, disk, or other resource exhaustion
  - :logic - Programming logic errors, unexpected states
  - :external - Third-party service errors
  - :unknown - Uncategorized errors
  """
  def structure_error(error, context \\ %{}) do
    {category, reason} = categorize_error(error)
    
    enhanced_context = Map.merge(context, %{
      timestamp: System.system_time(:millisecond),
      node: Node.self(),
      error_category: category,
      error_reason: reason
    })
    
    {:error, {category, reason, enhanced_context}}
  end

  ## Event Registration and Management

  @doc "Get all telemetry events emitted by Scout"
  def events do
    @trial_events ++ @study_events ++ @sampler_events ++ @store_events ++ @executor_events
  end

  @doc "Attach default telemetry handler with proper logging levels"
  def attach_default_logger do
    :telemetry.attach_many(
      "scout-enhanced-logger",
      events(),
      &handle_event/4,
      %{}
    )
  end

  @doc "Enhanced telemetry handler with appropriate log levels"
  def handle_event([:scout, _, _, :error] = event, _measurements, metadata, _config) do
    Logger.error("Scout error: #{inspect(event)} #{format_error_context(metadata)}")
  end

  def handle_event([:scout, _, _, :timeout] = event, _measurements, metadata, _config) do  
    Logger.warn("Scout timeout: #{inspect(event)} #{format_context(metadata)}")
  end

  def handle_event([:scout, _, _, :fallback] = event, _measurements, metadata, _config) do
    Logger.warn("Scout fallback: #{inspect(event)} #{format_context(metadata)}")
  end

  def handle_event([:scout, :study, :start] = event, _measurements, metadata, _config) do
    Logger.info("Scout: #{inspect(event)} #{format_context(metadata)}")
  end

  def handle_event([:scout, :study, :complete] = event, _measurements, metadata, _config) do
    Logger.info("Scout: #{inspect(event)} #{format_context(metadata)}")
  end

  def handle_event(event, _measurements, metadata, _config) do
    Logger.debug("Scout: #{inspect(event)} #{format_context(metadata)}")
  end

  ## Backward Compatibility with Original Scout.Telemetry

  # Legacy compatibility functions
  @doc false
  def study_event(:start, meas, meta), do: study_start(meas, meta)
  @doc false  
  def study_event(:stop, meas, meta), do: study_complete(meas, meta)
  @doc false
  def trial_event(:start, meas, meta), do: trial_start(meas, meta)
  @doc false
  def trial_event(:stop, meas, meta), do: trial_complete(meas, meta)
  @doc false
  def trial_event(:prune, meas, meta), do: trial_prune(meas, meta)

  ## Private Implementation

  @spec categorize_error(term()) :: {atom(), term()}
  defp categorize_error(%ArgumentError{} = error), do: {:validation, error.message}
  defp categorize_error(%ArithmeticError{} = error), do: {:arithmetic, error.message}
  defp categorize_error(%Protocol.UndefinedError{} = error), do: {:logic, inspect(error)}
  defp categorize_error(%FunctionClauseError{} = error), do: {:logic, inspect(error)}
  defp categorize_error(%Ecto.InvalidChangesetError{} = error), do: {:database, inspect(error)}
  defp categorize_error(%Postgrex.Error{} = error), do: {:database, error.message}
  defp categorize_error(%Jason.DecodeError{} = error), do: {:validation, error.data}
  defp categorize_error(%File.Error{} = error), do: {:resource, error.reason}
  defp categorize_error({:timeout, reason}), do: {:timeout, reason}
  defp categorize_error({:error, reason}), do: {:external, reason}
  defp categorize_error(error) when is_binary(error), do: {:external, error}
  defp categorize_error(error) when is_atom(error), do: {:logic, error}
  defp categorize_error(error), do: {:unknown, inspect(error)}

  @spec enhance_error_metadata(map()) :: map()
  defp enhance_error_metadata(metadata) do
    case Map.get(metadata, :error) do
      nil -> metadata
      error ->
        {category, reason} = categorize_error(error)
        Map.merge(metadata, %{
          error_category: category,
          error_reason: reason,
          error_message: Exception.message(error)
        })
    end
  end

  @spec format_context(map()) :: String.t()
  defp format_context(metadata) do
    relevant_keys = [:study_id, :trial_id, :trial_index, :sampler, :executor, :adapter]
    
    metadata
    |> Map.take(relevant_keys)
    |> Enum.filter(fn {_k, v} -> v != nil end)
    |> Enum.map(fn {k, v} -> "#{k}=#{v}" end)
    |> Enum.join(" ")
  end

  @spec format_error_context(map()) :: String.t()
  defp format_error_context(metadata) do
    base_context = format_context(metadata)
    
    error_parts = [
      Map.get(metadata, :error_category),
      Map.get(metadata, :error_message),
      Map.get(metadata, :error_reason)
    ]
    |> Enum.filter(& &1)
    |> Enum.join(": ")
    
    case error_parts do
      "" -> base_context
      error_info -> base_context <> " error=[" <> error_info <> "]"
    end
  end

  @spec ensure_measurements(map(), map()) :: map()
  defp ensure_measurements(measurements, defaults) do
    measurements
    |> ensure_map()
    |> (&Map.merge(defaults, &1)).()
  end

  @spec ensure_map(term()) :: map()
  defp ensure_map(val) when is_map(val), do: val
  defp ensure_map(_), do: %{}

  @spec emit_event([atom()], map(), map()) :: :ok
  defp emit_event(event_name, measurements, metadata) do
    try do
      :telemetry.execute(event_name, measurements, metadata)
    rescue
      # Gracefully handle missing telemetry dependency
      UndefinedFunctionError -> :ok
    end
  end
end