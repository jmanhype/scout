defmodule Scout.Recorder do
  @moduledoc """
  Records Scout telemetry events to newline-delimited JSON for playback.
  
  Enables deterministic reproduction of optimization runs by capturing:
  - All telemetry events with timestamps
  - RNG seeds used
  - Parameter suggestions and scores
  
  ## Usage
  
      # Start recording
      Scout.Recorder.start_recording("/tmp/run.ndjson")
      
      # Run your study...
      
      # Stop recording  
      Scout.Recorder.stop_recording()
  """
  
  use GenServer
  require Logger
  
  @events Scout.Telemetry.list_events()
  
  # Client API
  
  @doc """
  Start recording telemetry events to a file.
  """
  def start_recording(output_path) do
    GenServer.start_link(__MODULE__, output_path, name: __MODULE__)
  end
  
  @doc """
  Stop recording and close the file.
  """
  def stop_recording do
    GenServer.stop(__MODULE__)
  end
  
  @doc """
  Check if currently recording.
  """
  def recording? do
    GenServer.whereis(__MODULE__) != nil
  end
  
  # Server callbacks
  
  @impl true
  def init(output_path) do
    # Open file for writing
    case File.open(output_path, [:write, :utf8]) do
      {:ok, file} ->
        # Attach to all Scout telemetry events
        handler_id = "scout-recorder-#{System.unique_integer([:positive])}"
        
        :telemetry.attach_many(
          handler_id,
          @events,
          &__MODULE__.handle_event/4,
          %{pid: self()}
        )
        
        Logger.info("Scout Recorder started, writing to #{output_path}")
        
        {:ok, %{
          file: file,
          handler_id: handler_id,
          event_count: 0,
          start_time: System.system_time(:millisecond)
        }}
        
      {:error, reason} ->
        {:stop, {:file_error, reason}}
    end
  end
  
  @impl true
  def handle_cast({:record, event_name, measurements, metadata}, state) do
    # Build event record
    record = %{
      event: Enum.join(event_name, "."),
      timestamp: System.system_time(:millisecond),
      elapsed_ms: System.system_time(:millisecond) - state.start_time,
      measurements: measurements,
      metadata: sanitize_metadata(metadata)
    }
    
    # Write as NDJSON
    line = Jason.encode!(record) <> "\n"
    IO.write(state.file, line)
    
    {:noreply, %{state | event_count: state.event_count + 1}}
  end
  
  @impl true
  def terminate(_reason, state) do
    # Write summary record
    summary = %{
      event: "scout.recording.completed",
      timestamp: System.system_time(:millisecond),
      total_events: state.event_count,
      duration_ms: System.system_time(:millisecond) - state.start_time
    }
    
    IO.write(state.file, Jason.encode!(summary) <> "\n")
    File.close(state.file)
    
    # Detach telemetry handler
    :telemetry.detach(state.handler_id)
    
    Logger.info("Scout Recorder stopped, recorded #{state.event_count} events")
    :ok
  end
  
  # Telemetry handler
  
  def handle_event(event_name, measurements, metadata, %{pid: recorder_pid}) do
    GenServer.cast(recorder_pid, {:record, event_name, measurements, metadata})
  end
  
  # Helpers
  
  defp sanitize_metadata(metadata) do
    # Remove functions and other non-serializable data
    metadata
    |> Enum.filter(fn {_k, v} -> 
      not is_function(v) and not is_pid(v) and not is_reference(v)
    end)
    |> Enum.into(%{})
  end
end