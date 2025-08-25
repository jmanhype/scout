
import Config

# Postgres (required for v0.3 durability)
config :scout, Scout.Repo,
  url: System.get_env("DATABASE_URL") || "postgres://postgres:postgres@localhost:5432/scout_dev",
  pool_size: 10

# Oban
config :scout, Oban,
  repo: Scout.Repo,
  queues: [scout_trials: 50],
  plugins: [Oban.Plugins.Pruner]

# Store adapter (Scout.Store.ETS or Scout.Store.Postgres)
config :scout, :store_adapter, Scout.Store.Postgres
