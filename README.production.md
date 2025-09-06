# Production Deployment Guide

This guide covers deploying your Rails 7.1.5 application with all required services (PostgreSQL, Redis, Elasticsearch, Kafka) using Docker and Docker Compose.

## Architecture Overview

The production setup uses a multi-container architecture with the following services:

- **Web**: Rails application server (Puma)
- **Sidekiq**: Background job processing
- **PostgreSQL**: Primary database
- **Redis**: Session store and Sidekiq queue
- **Elasticsearch**: Search functionality
- **Kafka**: Message streaming (with Zookeeper)
- **Nginx**: Reverse proxy and load balancer

## Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+
- At least 4GB RAM available for containers
- SSL certificates (for HTTPS setup)

## Quick Start

### 1. Environment Setup

Copy the environment template and configure your values:

```bash
cp .env.production.example .env.production
```

Edit `.env.production` and set:
- `SECRET_KEY_BASE` - Generate with `rails secret`
- `RAILS_MASTER_KEY` - Copy from `config/master.key`
- `POSTGRES_PASSWORD` - Strong password for database
- Other service URLs (defaults should work for Docker Compose)

### 2. Generate Required Keys

```bash
# Generate secret key base
rails secret

# Ensure you have a master key
cat config/master.key
```

### 3. Deploy

```bash
./deploy.sh deploy
```

This will:
- Build the Rails application image
- Start all services with health checks
- Run database migrations
- Perform health checks
- Clean up old images

### 4. Verify Deployment

Check that all services are running:

```bash
./deploy.sh status
```

Access your application at `http://localhost` or your configured domain.

## Available Commands

The `deploy.sh` script provides several useful commands:

```bash
# Check environment configuration
./deploy.sh check

# Create database backup
./deploy.sh backup

# Full deployment (default)
./deploy.sh deploy

# Run health checks
./deploy.sh health

# View application logs
./deploy.sh logs

# Show container status
./deploy.sh status

# Stop all services
./deploy.sh stop

# Restart all services
./deploy.sh restart

# Clean up old Docker images
./deploy.sh cleanup
```

## Service Access

Once deployed, services are available at:

- **Web Application**: http://localhost (port 80)
- **PostgreSQL**: localhost:5432
- **Redis**: localhost:6379
- **Elasticsearch**: localhost:9200
- **Kafka**: localhost:9092

## Configuration Files

### Docker Files
- `Dockerfile.production` - Production-optimized Rails application image
- `docker-compose.production.yml` - Multi-service orchestration

### Configuration
- `.env.production` - Environment variables
- `nginx/nginx.conf` - Nginx reverse proxy configuration
- `deploy.sh` - Deployment automation script

## SSL/HTTPS Setup

To enable HTTPS:

1. Obtain SSL certificates for your domain
2. Place certificates in `nginx/ssl/`:
   - `your-domain.crt`
   - `your-domain.key`
3. Uncomment the HTTPS server block in `nginx/nginx.conf`
4. Update the server_name directive with your domain
5. Redeploy: `./deploy.sh deploy`

## Monitoring and Logs

### View Logs
```bash
# All services
./deploy.sh logs

# Specific service
docker-compose -f docker-compose.production.yml logs -f web
docker-compose -f docker-compose.production.yml logs -f sidekiq
```

### Health Checks
All services include health checks that Docker monitors automatically.

### Manual Health Checks
```bash
# Rails application
curl -f http://localhost/up

# Elasticsearch
curl -f http://localhost:9200/_health

# Redis
docker-compose -f docker-compose.production.yml exec redis redis-cli ping
```

## Database Management

### Backups
```bash
# Create backup
./deploy.sh backup

# Restore from backup
docker-compose -f docker-compose.production.yml exec -T postgres psql \
  -U postgres -d test_rails_71_app_production < backups/db_backup_TIMESTAMP.sql
```

### Migrations
```bash
# Run migrations
docker-compose -f docker-compose.production.yml run --rm web bin/rails db:migrate

# Rollback migration
docker-compose -f docker-compose.production.yml run --rm web bin/rails db:rollback
```

### Console Access
```bash
# Rails console
docker-compose -f docker-compose.production.yml exec web bin/rails console

# Database console
docker-compose -f docker-compose.production.yml exec postgres psql \
  -U postgres -d test_rails_71_app_production
```

## Scaling

To scale specific services:

```bash
# Scale web servers
docker-compose -f docker-compose.production.yml up -d --scale web=3

# Scale Sidekiq workers
docker-compose -f docker-compose.production.yml up -d --scale sidekiq=2
```

Update the Nginx configuration to load balance between multiple web containers.

## Security Considerations

### Container Security
- All services run as non-root users where possible
- Sensitive data is passed via environment variables
- Network isolation between services

### Application Security
- Security headers configured in Nginx
- Rate limiting for authentication endpoints
- Static asset serving with proper caching headers

### Database Security
- PostgreSQL runs in isolated container
- Access restricted to application containers only
- Regular automated backups

## Troubleshooting

### Common Issues

**Services not starting:**
```bash
# Check service logs
./deploy.sh logs

# Check container status
./deploy.sh status

# Restart services
./deploy.sh restart
```

**Database connection issues:**
```bash
# Check PostgreSQL health
docker-compose -f docker-compose.production.yml exec postgres pg_isready -U postgres

# Verify environment variables
docker-compose -f docker-compose.production.yml exec web env | grep DATABASE_URL
```

**Memory issues:**
```bash
# Check resource usage
docker stats

# Adjust Elasticsearch memory
# Edit docker-compose.production.yml ES_JAVA_OPTS
```

### Performance Tuning

**Database:**
- Adjust PostgreSQL shared_buffers and max_connections
- Consider read replicas for heavy read workloads

**Redis:**
- Configure maxmemory and eviction policies
- Use Redis clustering for high availability

**Elasticsearch:**
- Tune JVM heap size based on available memory
- Configure index settings for your data patterns

**Rails:**
- Adjust Puma worker and thread counts
- Configure caching strategies

## Maintenance

### Regular Tasks
- Monitor disk usage for logs and data volumes
- Update base Docker images regularly
- Backup database before major deployments
- Monitor application performance and errors

### Updates
```bash
# Update base images
docker-compose -f docker-compose.production.yml pull

# Rebuild and deploy
./deploy.sh deploy
```

## Support

For deployment issues:
1. Check service logs: `./deploy.sh logs`
2. Verify health checks: `./deploy.sh health`
3. Review environment configuration: `./deploy.sh check`

For application-specific issues, refer to the main application documentation.
