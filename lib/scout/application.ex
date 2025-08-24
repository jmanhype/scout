defmodule Scout.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    # Core Scout components that are always needed
    base_children = [
      {Scout.Store, []},
      {Task.Supervisor, name: Scout.TaskSupervisor}
    ]
    
    # Dashboard components only if enabled in config
    dashboard_children = 
      if Application.get_env(:scout, :dashboard_enabled, true) do
        [
          # Phoenix PubSub for dashboard
          {Phoenix.PubSub, name: ScoutDashboard.PubSub},
          # Dashboard telemetry listener
          ScoutDashboard.TelemetryListener,
          # Phoenix endpoint
          ScoutDashboardWeb.Endpoint
        ]
      else
        []
      end

    children = base_children ++ dashboard_children
    
    Supervisor.start_link(children, strategy: :one_for_one, name: Scout.Supervisor)
  end
end