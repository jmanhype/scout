# Start the Phoenix server in the foreground
{:ok, _} = Application.ensure_all_started(:scout)
{:ok, _} = Application.ensure_all_started(:phoenix)
{:ok, _} = Application.ensure_all_started(:phoenix_live_view)

# Configure endpoint
Application.put_env(:scout, ScoutDashboardWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: String.duplicate("a", 64),
  render_errors: [view: ScoutDashboardWeb.ErrorView, accepts: ~w(html json)],
  pubsub_server: Scout.PubSub,
  live_view: [signing_salt: "aaaaaaaa"],
  http: [port: 4050],
  server: true
)

# Start endpoint
{:ok, _} = ScoutDashboardWeb.Endpoint.start_link()

IO.puts("\n🌐 SCOUT DASHBOARD STARTED")
IO.puts("📍 Visit: http://localhost:4050")
IO.puts("📝 Study ID to monitor: working-demo")
IO.puts("\nPress Ctrl+C to stop...")

# Keep running
Process.sleep(:infinity)