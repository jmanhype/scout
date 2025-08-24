# 🚀 Scout Production Deployment Guide

## Docker Deployment

### Quick Start
```bash
# Clone and setup
git clone <scout-repo>
cd scout

# Environment setup  
cp config.sample.exs config/config.exs
export DB_PASSWORD="your-secure-password"
export SECRET_KEY_BASE="$(openssl rand -base64 48)"

# Deploy with Docker Compose
docker-compose up -d

# Check status
docker-compose ps
```

### Accessing Services
- **Scout Dashboard**: http://localhost:4050
- **Grafana Monitoring**: http://localhost:3000 (admin/admin)
- **Prometheus Metrics**: http://localhost:9090
- **PostgreSQL**: localhost:5432

---

## Kubernetes Deployment

### Prerequisites
```bash
# Required tools
kubectl, helm, docker

# Cluster requirements
- Kubernetes 1.20+
- Persistent Volume support
- Ingress controller (nginx)
- Cert-manager (optional, for HTTPS)
```

### Deploy to K8s
```bash
# Build and push image
docker build -t your-registry/scout:latest .
docker push your-registry/scout:latest

# Update image in deployment.yaml
sed -i 's/scout:latest/your-registry\/scout:latest/' k8s/deployment.yaml

# Deploy PostgreSQL
kubectl apply -f k8s/postgres.yaml

# Deploy Scout application
kubectl apply -f k8s/secrets.yaml
kubectl apply -f k8s/deployment.yaml

# Check deployment
kubectl get pods -l app=scout
kubectl get svc scout-service
```

### Scaling
```bash
# Horizontal scaling
kubectl scale deployment scout-app --replicas=5

# Resource adjustment
kubectl patch deployment scout-app -p '{"spec":{"template":{"spec":{"containers":[{"name":"scout","resources":{"requests":{"cpu":"500m","memory":"512Mi"}}}]}}}}'
```

---

## Environment Variables

### Required
```bash
DATABASE_URL=postgres://user:pass@host:port/dbname
SECRET_KEY_BASE=64-char-secret-for-phoenix
```

### Optional
```bash
PORT=4050                    # Application port
HOST=0.0.0.0                # Bind address  
MIX_ENV=prod                # Environment
GRAFANA_PASSWORD=admin      # Grafana admin password
OBAN_QUEUES=scout_trials:50 # Job queue configuration
```

---

## Monitoring & Observability

### Metrics Available
- `scout_active_studies_total` - Number of running studies
- `scout_trials_total` - Total trials executed
- `scout_trials_duration_seconds` - Trial execution time
- `scout_best_score` - Best objective value per study

### Health Endpoints
- `GET /health` - Application health check
- `GET /metrics` - Prometheus metrics
- `GET /` - Dashboard interface

### Grafana Dashboard
Pre-configured dashboard includes:
- Active studies count
- Trial throughput
- Study convergence plots
- System resource usage

---

## Security Considerations

### Production Checklist
- [ ] Generate secure `SECRET_KEY_BASE` (64+ chars)
- [ ] Use strong database passwords
- [ ] Enable HTTPS with valid certificates
- [ ] Configure firewall rules (ports 22, 80, 443, 4050)
- [ ] Regular security updates
- [ ] Monitor access logs
- [ ] Backup database regularly

### Network Security
```bash
# Firewall rules (example)
ufw allow 22/tcp     # SSH
ufw allow 80/tcp     # HTTP
ufw allow 443/tcp    # HTTPS
ufw allow 4050/tcp   # Scout dashboard
ufw --force enable
```

---

## Database Management

### Migrations
```bash
# Run migrations in production
docker-compose exec scout mix ecto.migrate

# In Kubernetes
kubectl exec -it deployment/scout-app -- mix ecto.migrate
```

### Backups
```bash
# PostgreSQL backup
docker-compose exec postgres pg_dump -U scout scout_prod > backup_$(date +%Y%m%d).sql

# In Kubernetes
kubectl exec -it postgres-0 -- pg_dump -U scout scout_prod > backup.sql
```

### Restore
```bash
# Restore from backup
docker-compose exec -T postgres psql -U scout scout_prod < backup.sql
```

---

## Troubleshooting

### Common Issues
1. **Port already in use**: Change PORT env var
2. **Database connection failed**: Check DATABASE_URL
3. **Phoenix secret error**: Set SECRET_KEY_BASE
4. **Memory issues**: Increase container limits

### Debug Commands
```bash
# Check logs
docker-compose logs scout
kubectl logs -f deployment/scout-app

# Container shell access
docker-compose exec scout sh
kubectl exec -it deployment/scout-app -- sh

# Database access
docker-compose exec postgres psql -U scout scout_prod
```

### Performance Tuning
```yaml
# Docker Compose resource limits
scout:
  deploy:
    resources:
      limits:
        cpus: '2.0'
        memory: 2G
      reservations:
        cpus: '0.5'
        memory: 512M
```

---

## High Availability Setup

### Multi-node Configuration
```bash
# Multiple Scout instances
docker-compose up --scale scout=3

# Load balancer (nginx)
upstream scout_backend {
    server scout:4050;
    server scout_2:4050;  
    server scout_3:4050;
}
```

### Database Replication
```yaml
# PostgreSQL streaming replication
postgres-primary:
  image: postgres:16
  environment:
    POSTGRES_REPLICATION_MODE: master
    
postgres-replica:
  image: postgres:16
  environment:
    POSTGRES_REPLICATION_MODE: slave
    POSTGRES_MASTER_SERVICE: postgres-primary
```

**Scout is now production-ready with full Docker/K8s deployment infrastructure!** 🎯