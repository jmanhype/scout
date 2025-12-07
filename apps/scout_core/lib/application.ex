defmodule Scout.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    # Database components (only if PostgreSQL adapter is configured)
    repo_children = 
      if Application.get_env(:scout_core, :store_adapter) == Scout.Store.Postgres do
        [Scout.Repo]
      else
        []
      end
    
    # Core Scout components that are always needed
    base_children = [
      {Scout.Store, []},
      {Task.Supervisor, name: Scout.TaskSupervisor}
    ]

    children = repo_children ++ base_children
    
    Supervisor.start_link(children, strategy: :one_for_one, name: Scout.Supervisor)
  end
end