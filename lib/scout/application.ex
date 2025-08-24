defmodule Scout.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Scout.Store, []},
      {Task.Supervisor, name: Scout.TaskSupervisor},
      # Phoenix PubSub for dashboard
      {Phoenix.PubSub, name: ScoutDashboard.PubSub},
      # Dashboard telemetry listener
      ScoutDashboard.TelemetryListener,
      # Phoenix endpoint
      ScoutDashboardWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Scout.Supervisor)
  end
end
