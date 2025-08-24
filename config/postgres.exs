# PostgreSQL Configuration for Scout
#
# To use PostgreSQL storage instead of ETS:
# 1. Copy this file to config/config.exs or import it
# 2. Update database credentials below
# 3. Run: mix ecto.create && mix ecto.migrate
# 4. Start Scout normally

import Config

# Configure Scout to use PostgreSQL adapter
config :scout, :store_adapter, Scout.Store.Postgres

# Database configuration
config :scout, Scout.Repo,
  username: System.get_env("DB_USER", "postgres"),
  password: System.get_env("DB_PASSWORD", "postgres"),
  hostname: System.get_env("DB_HOST", "localhost"),
  database: System.get_env("DB_NAME", "scout_dev"),
  pool_size: String.to_integer(System.get_env("DB_POOL_SIZE", "10")),
  show_sensitive_data_on_connection_error: true

# Add the Repo to the supervision tree
config :scout,
  ecto_repos: [Scout.Repo]

# Optional: Configure Oban for distributed job processing
config :scout, Oban,
  repo: Scout.Repo,
  plugins: [
    {Oban.Plugins.Pruner, max_age: 86_400},  # Prune completed jobs after 1 day
    {Oban.Plugins.Stager, interval: 1_000}   # Stage available jobs every second
  ],
  queues: [
    default: 10,        # Default queue with 10 concurrent workers
    optimization: 20,   # Optimization queue with 20 concurrent workers
    export: 5          # Export queue with 5 concurrent workers
  ]

# Benefits of PostgreSQL storage:
# - Persistent storage across restarts
# - Distributed optimization across multiple nodes
# - Better crash recovery
# - SQL querying capabilities for analysis
# - Integration with existing data pipelines
#
# Trade-offs:
# - Slightly higher latency than ETS
# - Requires PostgreSQL setup and maintenance
# - Database connection overhead