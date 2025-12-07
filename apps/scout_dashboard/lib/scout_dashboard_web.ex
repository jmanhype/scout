
defmodule ScoutDashboardWeb do
  def controller do
    quote do
      use Phoenix.Controller, formats: [:html, :json], layouts: [html: ScoutDashboardWeb.Layouts]
      import Plug.Conn
      import Phoenix.Controller
      alias ScoutDashboardWeb.Router.Helpers, as: Routes
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {ScoutDashboardWeb.Layouts, :root}

      unquote(verified_routes())
      import Phoenix.HTML
      alias ScoutDashboardWeb.Router.Helpers, as: Routes
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent
      alias ScoutDashboardWeb.Router.Helpers, as: Routes
    end
  end

  def html do
    quote do
      use Phoenix.Component
      import Phoenix.HTML
      unquote(verified_routes())
      alias ScoutDashboardWeb.Router.Helpers, as: Routes
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: ScoutDashboardWeb.Endpoint,
        router: ScoutDashboardWeb.Router,
        statics: ScoutDashboardWeb.static_paths()
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end

  def static_paths, do: ~w(assets images favicon.ico robots.txt)
end
