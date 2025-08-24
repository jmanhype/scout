
defmodule ScoutDashboardWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :scout

  @session_options [
    store: :cookie,
    key: "_scout_dashboard_key",
    signing_salt: "salt123"
  ]

  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]

  plug Plug.Static,
    at: "/",
    from: :scout,
    gzip: false,
    only: ScoutDashboardWeb.static_paths()

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Session, @session_options
  plug ScoutDashboardWeb.Router
end
