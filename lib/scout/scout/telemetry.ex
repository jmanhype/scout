defmodule Scout.Telemetry do
  @moduledoc """
  Frozen telemetry event matrix for Scout.
  
  This is the SINGLE SOURCE OF TRUTH for all telemetry events.
  All components MUST emit exactly these events with these payloads.
  No deviations allowed.
  
  ## Event Naming Convention
  
  All events follow the pattern: `[:scout, component, action]`
  
  ## Measurement Units
  
  - All durations in MICROSECONDS
  - All timestamps in UNIX milliseconds
  - All counts are integers
  - All scores are floats
  
  ## Metadata Guarantees
  
  Every event includes AT MINIMUM:
  - `:study_id` - String identifier
  - `:timestamp` - Unix milliseconds
  
  ## Event Matrix
  
  See individual event documentation for detailed contracts.
  """
  
  # ============================================================================
  # STUDY LIFECYCLE EVENTS
  # ============================================================================
  
  @doc """
  Study created event.
  
  Event: `[:scout, :study, :created]`
  
  Measurements:
  - `:timestamp` - Creation time (ms)
  
  Metadata:
  - `:study_id` - Study identifier
  - `:goal` - Either `:maximize` or `:minimize`
  - `:max_trials` - Maximum trial count (optional)
  - `:sampler` - Sampler module atom
  - `:pruner` - Pruner module atom (optional)
  """
  def study_created(study_id, goal, opts \\ %{}) do
    :telemetry.execute(
      [:scout, :study, :created],
      %{timestamp: System.system_time(:millisecond)},
      Map.merge(%{
        study_id: study_id,
        goal: goal,
        timestamp: System.system_time(:millisecond)
      }, opts)
    )
  end
  
  @doc """
  Study status changed event.
  
  Event: `[:scout, :study, :status_changed]`
  
  Measurements:
  - `:timestamp` - Change time (ms)
  
  Metadata:
  - `:study_id` - Study identifier
  - `:from_status` - Previous status atom
  - `:to_status` - New status atom
  - `:reason` - Change reason (optional)
  """
  def study_status_changed(study_id, from_status, to_status, reason \\ nil) do
    :telemetry.execute(
      [:scout, :study, :status_changed],
      %{timestamp: System.system_time(:millisecond)},
      %{
        study_id: study_id,
        from_status: from_status,
        to_status: to_status,
        reason: reason,
        timestamp: System.system_time(:millisecond)
      }
    )
  end
  
  @doc """
  Study completed event.
  
  Event: `[:scout, :study, :completed]`
  
  Measurements:
  - `:duration_ms` - Total study duration
  - `:trial_count` - Number of trials run
  - `:best_score` - Best objective value achieved
  
  Metadata:
  - `:study_id` - Study identifier
  - `:best_trial_id` - ID of best trial
  - `:best_params` - Parameters of best trial
  - `:pruned_count` - Number of pruned trials
  """
  def study_completed(study_id, measurements, metadata) do
    :telemetry.execute(
      [:scout, :study, :completed],
      Map.merge(%{timestamp: System.system_time(:millisecond)}, measurements),
      Map.merge(%{
        study_id: study_id,
        timestamp: System.system_time(:millisecond)
      }, metadata)
    )
  end
  
  # ============================================================================
  # TRIAL LIFECYCLE EVENTS
  # ============================================================================
  
  @doc """
  Trial started event.
  
  Event: `[:scout, :trial, :started]`
  
  Measurements:
  - `:trial_index` - 0-based trial number
  - `:timestamp` - Start time (ms)
  
  Metadata:
  - `:study_id` - Study identifier
  - `:trial_id` - Trial identifier
  - `:params` - Trial parameters map
  - `:bracket` - Bracket assignment (optional)
  - `:seed` - RNG seed (optional)
  """
  def trial_started(study_id, trial_id, trial_index, params, opts \\ %{}) do
    :telemetry.execute(
      [:scout, :trial, :started],
      %{
        trial_index: trial_index,
        timestamp: System.system_time(:millisecond)
      },
      Map.merge(%{
        study_id: study_id,
        trial_id: trial_id,
        params: params,
        timestamp: System.system_time(:millisecond)
      }, opts)
    )
  end
  
  @doc """
  Trial completed event.
  
  Event: `[:scout, :trial, :completed]`
  
  Measurements:
  - `:score` - Objective value
  - `:duration_us` - Trial duration in microseconds
  
  Metadata:
  - `:study_id` - Study identifier
  - `:trial_id` - Trial identifier
  - `:status` - Final status (`:completed`, `:failed`, `:pruned`)
  - `:error` - Error message if failed (optional)
  - `:metrics` - Additional metrics map (optional)
  """
  def trial_completed(study_id, trial_id, score, duration_us, status, opts \\ %{}) do
    :telemetry.execute(
      [:scout, :trial, :completed],
      %{
        score: score,
        duration_us: duration_us,
        timestamp: System.system_time(:millisecond)
      },
      Map.merge(%{
        study_id: study_id,
        trial_id: trial_id,
        status: status,
        timestamp: System.system_time(:millisecond)
      }, opts)
    )
  end
  
  @doc """
  Trial pruned event.
  
  Event: `[:scout, :trial, :pruned]`
  
  Measurements:
  - `:rung` - Checkpoint where pruned
  - `:score` - Score at pruning
  
  Metadata:
  - `:study_id` - Study identifier
  - `:trial_id` - Trial identifier
  - `:bracket` - Bracket assignment
  - `:reason` - Pruning reason
  """
  def trial_pruned(study_id, trial_id, rung, score, bracket, reason) do
    :telemetry.execute(
      [:scout, :trial, :pruned],
      %{
        rung: rung,
        score: score,
        timestamp: System.system_time(:millisecond)
      },
      %{
        study_id: study_id,
        trial_id: trial_id,
        bracket: bracket,
        reason: reason,
        timestamp: System.system_time(:millisecond)
      }
    )
  end
  
  # ============================================================================
  # SAMPLER EVENTS
  # ============================================================================
  
  @doc """
  Sampler suggestion event.
  
  Event: `[:scout, :sampler, :suggested]`
  
  Measurements:
  - `:trial_index` - Current trial number
  - `:history_size` - Number of completed trials
  - `:duration_us` - Time to generate suggestion
  
  Metadata:
  - `:study_id` - Study identifier
  - `:sampler` - Sampler module atom
  - `:params` - Suggested parameters
  """
  def sampler_suggested(study_id, sampler, trial_index, params, history_size, duration_us) do
    :telemetry.execute(
      [:scout, :sampler, :suggested],
      %{
        trial_index: trial_index,
        history_size: history_size,
        duration_us: duration_us,
        timestamp: System.system_time(:millisecond)
      },
      %{
        study_id: study_id,
        sampler: sampler,
        params: params,
        timestamp: System.system_time(:millisecond)
      }
    )
  end
  
  # ============================================================================
  # PRUNER EVENTS  
  # ============================================================================
  
  @doc """
  Pruner decision event.
  
  Event: `[:scout, :pruner, :decision]`
  
  Measurements:
  - `:rung` - Current checkpoint
  - `:percentile` - Percentile threshold used
  
  Metadata:
  - `:study_id` - Study identifier
  - `:trial_id` - Trial identifier
  - `:pruner` - Pruner module atom
  - `:decision` - Either `:keep` or `:prune`
  - `:scores_count` - Number of scores evaluated
  """
  def pruner_decision(study_id, trial_id, pruner, rung, decision, opts \\ %{}) do
    :telemetry.execute(
      [:scout, :pruner, :decision],
      %{
        rung: rung,
        percentile: opts[:percentile] || 0.0,
        timestamp: System.system_time(:millisecond)
      },
      Map.merge(%{
        study_id: study_id,
        trial_id: trial_id,
        pruner: pruner,
        decision: decision,
        timestamp: System.system_time(:millisecond)
      }, opts)
    )
  end
  
  # ============================================================================
  # EXECUTOR EVENTS
  # ============================================================================
  
  @doc """
  Executor batch started event.
  
  Event: `[:scout, :executor, :batch_started]`
  
  Measurements:
  - `:batch_size` - Number of trials in batch
  - `:timestamp` - Start time (ms)
  
  Metadata:
  - `:study_id` - Study identifier
  - `:executor` - Executor module atom
  - `:parallel` - Whether running in parallel
  """
  def executor_batch_started(study_id, executor, batch_size, parallel \\ false) do
    :telemetry.execute(
      [:scout, :executor, :batch_started],
      %{
        batch_size: batch_size,
        timestamp: System.system_time(:millisecond)
      },
      %{
        study_id: study_id,
        executor: executor,
        parallel: parallel,
        timestamp: System.system_time(:millisecond)
      }
    )
  end
  
  @doc """
  Executor batch completed event.
  
  Event: `[:scout, :executor, :batch_completed]`
  
  Measurements:
  - `:batch_size` - Number of trials completed
  - `:duration_ms` - Batch duration
  - `:success_count` - Successful trials
  - `:failure_count` - Failed trials
  
  Metadata:
  - `:study_id` - Study identifier
  - `:executor` - Executor module atom
  """
  def executor_batch_completed(study_id, executor, measurements) do
    :telemetry.execute(
      [:scout, :executor, :batch_completed],
      Map.merge(%{timestamp: System.system_time(:millisecond)}, measurements),
      %{
        study_id: study_id,
        executor: executor,
        timestamp: System.system_time(:millisecond)
      }
    )
  end
  
  # ============================================================================
  # STORAGE EVENTS
  # ============================================================================
  
  @doc """
  Storage operation event.
  
  Event: `[:scout, :store, :operation]`
  
  Measurements:
  - `:duration_us` - Operation duration
  
  Metadata:
  - `:study_id` - Study identifier (when applicable)
  - `:adapter` - Storage adapter atom
  - `:operation` - Operation name (e.g., `:put_study`, `:add_trial`)
  - `:success` - Boolean success indicator
  - `:error` - Error term if failed (optional)
  """
  def storage_operation(adapter, operation, duration_us, success, metadata \\ %{}) do
    :telemetry.execute(
      [:scout, :store, :operation],
      %{
        duration_us: duration_us,
        timestamp: System.system_time(:millisecond)
      },
      Map.merge(%{
        adapter: adapter,
        operation: operation,
        success: success,
        timestamp: System.system_time(:millisecond)
      }, metadata)
    )
  end
  
  # ============================================================================
  # ERROR EVENTS
  # ============================================================================
  
  @doc """
  Error occurred event.
  
  Event: `[:scout, :error, :occurred]`
  
  Measurements:
  - `:timestamp` - Error time (ms)
  
  Metadata:
  - `:study_id` - Study identifier (when applicable)
  - `:component` - Component where error occurred
  - `:error_type` - Error classification
  - `:message` - Error message
  - `:stacktrace` - Stacktrace (optional)
  """
  def error_occurred(component, error_type, message, metadata \\ %{}) do
    :telemetry.execute(
      [:scout, :error, :occurred],
      %{timestamp: System.system_time(:millisecond)},
      Map.merge(%{
        component: component,
        error_type: error_type,
        message: message,
        timestamp: System.system_time(:millisecond)
      }, metadata)
    )
  end
  
  # ============================================================================
  # TELEMETRY ATTACHMENT
  # ============================================================================
  
  @doc """
  Attach a handler to Scout telemetry events.
  
  ## Example
  
      Scout.Telemetry.attach_handler(
        "my-logger",
        [:scout, :trial, :completed],
        fn event, measurements, metadata, _config ->
          Logger.info("Trial completed: \#{metadata.trial_id}")
        end
      )
  """
  def attach_handler(handler_id, events, handler_fun, config \\ nil) do
    :telemetry.attach_many(handler_id, events, handler_fun, config)
  end
  
  @doc """
  List all Scout telemetry events.
  
  Returns a list of all event names that Scout emits.
  """
  def list_events do
    [
      # Study events
      [:scout, :study, :created],
      [:scout, :study, :status_changed],
      [:scout, :study, :completed],
      
      # Trial events
      [:scout, :trial, :started],
      [:scout, :trial, :completed],
      [:scout, :trial, :pruned],
      
      # Sampler events
      [:scout, :sampler, :suggested],
      
      # Pruner events
      [:scout, :pruner, :decision],
      
      # Executor events
      [:scout, :executor, :batch_started],
      [:scout, :executor, :batch_completed],
      
      # Storage events
      [:scout, :store, :operation],
      
      # Error events
      [:scout, :error, :occurred]
    ]
  end
  
  @doc """
  Get event specification.
  
  Returns detailed specification for a given event name.
  """
  def event_spec(event_name) do
    case event_name do
      [:scout, :study, :created] ->
        %{
          measurements: [:timestamp],
          metadata: [:study_id, :goal, :max_trials, :sampler, :pruner],
          required: [:study_id, :goal]
        }
        
      [:scout, :trial, :completed] ->
        %{
          measurements: [:score, :duration_us, :timestamp],
          metadata: [:study_id, :trial_id, :status, :error, :metrics],
          required: [:study_id, :trial_id, :status]
        }
        
      _ ->
        nil
    end
  end
end