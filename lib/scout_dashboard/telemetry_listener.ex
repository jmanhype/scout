
defmodule ScoutDashboard.TelemetryListener do
  use GenServer
  @events [
    [:scout, :trial, :start],
    [:scout, :trial, :stop],
    [:scout, :trial, :prune],
    [:scout, :study, :start],
    [:scout, :study, :stop]
  ]

  def start_link(_), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  @impl true
  def init(_) do
    for e <- @events, do: :telemetry.attach({__MODULE__, e}, e, &__MODULE__.handle_event/4, nil)
    {:ok, %{}}
  end

  def handle_event(_event, _measurements, _meta, _config) do
    # Bridge into PubSub or logs if you want; LiveView currently polls status
    :ok
  end
end
