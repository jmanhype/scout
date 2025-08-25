defmodule ScoutDashboard.TelemetryListener do
  @moduledoc """
  Listens to Scout telemetry events and broadcasts them to Phoenix channels.
  """
  use GenServer
  
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end
  
  @impl true
  def init(_) do
    # Attach to Scout telemetry events
    :telemetry.attach_many(
      "scout-dashboard-listener",
      [
        [:scout, :study, :created],
        [:scout, :study, :completed],
        [:scout, :trial, :started],
        [:scout, :trial, :completed],
        [:scout, :trial, :pruned]
      ],
      &__MODULE__.handle_event/4,
      nil
    )
    
    {:ok, %{}}
  end
  
  def handle_event(event, measurements, metadata, _config) do
    # Broadcast to Phoenix channels
    Phoenix.PubSub.broadcast(
      ScoutDashboard.PubSub,
      "scout:events",
      {event, measurements, metadata}
    )
  end
end