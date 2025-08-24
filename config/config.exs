
import Config

# Configure Ecto and database for Scout persistence
config :scout, Scout.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "scout_dev",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  pool_size: 10

config :scout, 
  ecto_repos: [Scout.Repo]

config :scout, ScoutDashboardWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: ScoutDashboardWeb.ErrorHTML, json: "error.json"],
    layout: false
  ],
  pubsub_server: ScoutDashboard.PubSub,
  live_view: [signing_salt: "r7Q6d3ko"],
  secret_key_base: "your-secret-key-base-at-least-64-bytes-long-for-production-security-purposes"

if config_env() == :dev do
  config :scout, ScoutDashboardWeb.Endpoint,
    http: [ip: {127,0,0,1}, port: 4050],
    debug_errors: true,
    code_reloader: true,
    check_origin: false,
    watchers: []
end

if config_env() == :prod do
  config :scout, ScoutDashboardWeb.Endpoint,
    url: [host: System.get_env("HOST", "example.com"), port: 443],
    http: [ip: {0,0,0,0}, port: String.to_integer(System.get_env("PORT") || "4050")],
    secret_key_base: System.get_env("SECRET_KEY_BASE") || "CHANGE_ME"
end
