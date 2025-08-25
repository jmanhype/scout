defmodule ScoutDashboard.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Phoenix PubSub for dashboard
      {Phoenix.PubSub, name: ScoutDashboard.PubSub},
      # Dashboard telemetry listener
      ScoutDashboard.TelemetryListener,
      # Phoenix endpoint
      ScoutDashboardWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: ScoutDashboard.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ScoutDashboardWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end