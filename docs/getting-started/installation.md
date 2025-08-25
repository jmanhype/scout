# Installation

Scout can be installed and deployed in multiple ways depending on your needs.

## Quick Install (Development)

### Prerequisites
- Elixir 1.14+ 
- PostgreSQL 14+ (optional, for persistent storage)
- Docker (optional, for containerized deployment)

### Via Hex Package Manager

```elixir
# Add to your mix.exs deps
defp deps do
  [
    {:scout, "~> 0.3"},
    # Auto-included: Phoenix LiveView, Oban, Ecto
  ]
end
```

### Setup Steps

```bash
# 1. Install dependencies
mix deps.get

# 2. Configure database (optional)
cp config.sample.exs config/config.exs
# Edit config/config.exs with your PostgreSQL credentials

# 3. Create and migrate database
mix ecto.create
mix ecto.migrate

# 4. Run Scout with dashboard
mix scout.server

# Dashboard available at http://localhost:4050
```

## Docker Installation

### Quick Start with Docker Compose

```bash
# Clone the repository
git clone https://github.com/your-org/scout.git
cd scout

# Set environment variables
export DB_PASSWORD="your-secure-password"
export SECRET_KEY_BASE="$(openssl rand -base64 48)"

# Start all services
docker-compose up -d

# Access services:
# - Scout Dashboard: http://localhost:4050
# - Grafana: http://localhost:3000
# - Prometheus: http://localhost:9090
```

### Building Custom Docker Image

```dockerfile
# Use the provided Dockerfile
docker build -t scout:latest .

# Run with environment variables
docker run -d \
  -p 4050:4050 \
  -e DATABASE_URL="postgresql://user:pass@host/db" \
  -e SECRET_KEY_BASE="your-secret" \
  scout:latest
```

## Kubernetes Deployment

For production deployments, see our [Kubernetes Deployment Guide](../deployment/kubernetes.md).

```bash
# Quick deployment
kubectl apply -f k8s/

# Check status
kubectl get pods -n scout
```

## Configuration Options

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PORT` | HTTP port for dashboard | 4050 |
| `DATABASE_URL` | PostgreSQL connection string | - |
| `SECRET_KEY_BASE` | Phoenix secret key | - |
| `DASHBOARD_ENABLED` | Enable web dashboard | true |
| `PARALLELISM` | Default trial parallelism | 4 |

### Minimal Configuration

For quick testing without PostgreSQL:

```elixir
# config/config.exs
config :scout,
  store_adapter: Scout.Store.Memory,
  dashboard_enabled: true,
  port: 4050
```

## Verify Installation

```bash
# Run the test suite
mix test

# Try a simple optimization
mix run examples/quick_start.exs

# Check dashboard
open http://localhost:4050
```

## Next Steps

- Follow the [Quick Start Guide](quickstart.md) to run your first optimization
- Explore [Examples](examples.md) for real-world use cases
- Learn about [DSPy Integration](../concepts/dspy-integration.md)