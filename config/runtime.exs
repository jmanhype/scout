
import Config
if config_env() == :prod do
  secret = System.get_env("SECRET_KEY_BASE") || Base.encode64(:crypto.strong_rand_bytes(48))
  config :scout_dashboard, ScoutDashboardWeb.Endpoint, secret_key_base: secret
end
