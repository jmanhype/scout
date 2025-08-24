
defmodule ScoutDashboard.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: ScoutDashboard.PubSub},
      ScoutDashboardWeb.Endpoint,
      ScoutDashboard.TelemetryListener,
      Scout.Store
    ]

    opts = [strategy: :one_for_one, name: ScoutDashboard.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
