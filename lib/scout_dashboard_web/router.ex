
defmodule ScoutDashboardWeb.Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {ScoutDashboardWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", ScoutDashboardWeb do
    pipe_through :browser
    live "/", HomeLive, :index
    live "/studies/:id", DashboardLive, :show
    get "/optimize/:study_id", OptimizeController, :run
    get "/populate/:study_id", PopulateController, :run
    get "/debug/:study_id", DebugController, :test
  end
end
