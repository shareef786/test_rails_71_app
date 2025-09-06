# Azure Kubernetes Service (AKS) Deployment Guide

This guide covers deploying your Rails 7.1.5 application to Azure Kubernetes Service (AKS) with all required services (PostgreSQL, Redis, Elasticsearch, Kafka) using Kubernetes manifests.

## Architecture Overview

The AKS deployment uses a microservices architecture with the following components:

- **Rails Web**: Horizontal Pod Autoscaler enabled (2-10 replicas)
- **Sidekiq**: Background job processing (1-5 replicas)
- **PostgreSQL**: Database with persistent storage (20GB)
- **Redis**: Session store and job queue (5GB)
- **Elasticsearch**: Search functionality (50GB)
- **Kafka + Zookeeper**: Message streaming (10GB + 5GB)
- **NGINX Ingress**: Load balancer with SSL termination
- **Cert-Manager**: Automatic SSL certificate management

## Prerequisites

### Required Tools
- Azure CLI (`az`) - [Installation Guide](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- kubectl - [Installation Guide](https://kubernetes.io/docs/tasks/tools/)
- Helm 3+ - [Installation Guide](https://helm.sh/docs/intro/install/)
- Docker - [Installation Guide](https://docs.docker.com/get-docker/)

### Azure Resources
- Azure subscription with sufficient quota for AKS
- Resource group (created by script)
- Azure Container Registry (created by script)
- AKS cluster (created by script)

## Quick Start

### 1. Login to Azure

```bash
az login
az account set --subscription \"your-subscription-id\"
```

### 2. Configure Environment (Optional)

```bash
export RESOURCE_GROUP=\"rails-app-rg\"
export CLUSTER_NAME=\"rails-app-aks\"
export LOCATION=\"East US\"
export ACR_NAME=\"railsappacr$(date +%s)\"  # Must be globally unique
```

### 3. Deploy to AKS

```bash
./deploy-aks.sh deploy
```

This will:
- Create Azure resources (Resource Group, ACR, AKS cluster)
- Build and push your Docker image to ACR
- Install NGINX Ingress Controller
- Install Cert-Manager for SSL
- Create Kubernetes secrets
- Deploy all services
- Provide the external IP address

### 4. Configure DNS

Point your domain to the external IP provided by the script:

```bash
# Get the IP address
./deploy-aks.sh ip
```

Update your DNS records to point to this IP address.

## Deployment Commands

The `deploy-aks.sh` script provides several commands:

```bash
# Setup Azure infrastructure only
./deploy-aks.sh setup

# Build and push Docker image only
./deploy-aks.sh build

# Create secrets only
./deploy-aks.sh secrets

# Full deployment (default)
./deploy-aks.sh deploy

# Check application status
./deploy-aks.sh status

# View logs (specify service name)
./deploy-aks.sh logs rails-web
./deploy-aks.sh logs sidekiq

# Run health checks
./deploy-aks.sh health

# Get ingress IP
./deploy-aks.sh ip

# Clean up all resources
./deploy-aks.sh cleanup
```

## Configuration

### Secrets Management

The deployment script creates a `secrets.env` file template. Edit this file with your actual values:

```bash
# secrets.env
SECRET_KEY_BASE=your_generated_secret_key_base
RAILS_MASTER_KEY=your_rails_master_key_from_config_master_key
POSTGRES_PASSWORD=your_secure_database_password
```

### Domain Configuration

Update the ingress configuration with your domain:

```bash
# Edit k8s/base/ingress.yaml
sed -i 's/your-domain.com/yourdomain.com/g' k8s/base/ingress.yaml
sed -i 's/your-email@example.com/admin@yourdomain.com/g' k8s/base/ingress.yaml
```

### Resource Scaling

The deployment includes Horizontal Pod Autoscalers (HPA):

- **Rails Web**: 2-10 pods (CPU: 70%, Memory: 80%)
- **Sidekiq**: 1-5 pods (CPU: 70%)

Adjust these in `k8s/base/rails-app.yaml` if needed.

## Storage Classes

The deployment uses Azure-specific storage classes:

- **managed-premium**: High-performance SSD for databases
- **azurefile-premium**: Shared storage for Rails application files

## Security Features

### Network Policies
- Pod-to-pod communication is restricted
- Only necessary ports are exposed
- External traffic only through ingress

### Security Headers
- X-Frame-Options: DENY
- X-Content-Type-Options: nosniff
- X-XSS-Protection: enabled
- Content Security Policy configured
- Referrer Policy: strict-origin-when-cross-origin

### SSL/TLS
- Automatic certificate provisioning via Let's Encrypt
- HTTP to HTTPS redirects
- TLS 1.2+ enforcement

## Monitoring and Observability

### Azure Monitor Integration
The AKS cluster is configured with Azure Monitor for containers:

```bash
# View cluster insights in Azure Portal
az aks browse --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME
```

### Application Logs

```bash
# View all pods
kubectl get pods -n rails-app

# View specific service logs
kubectl logs -f deployment/rails-web -n rails-app
kubectl logs -f deployment/sidekiq -n rails-app
kubectl logs -f deployment/postgres -n rails-app

# View ingress controller logs
kubectl logs -f deployment/ingress-nginx-controller -n ingress-nginx
```

### Health Checks

All services include comprehensive health checks:
- Liveness probes to restart unhealthy containers
- Readiness probes to manage traffic routing
- Health check endpoints for external monitoring

## Database Management

### Migrations

Database migrations run automatically via init containers on each deployment.

For manual migration management:

```bash
# Run migrations manually
kubectl exec -it deployment/rails-web -n rails-app -- bin/rails db:migrate

# Rollback migrations
kubectl exec -it deployment/rails-web -n rails-app -- bin/rails db:rollback

# Access Rails console
kubectl exec -it deployment/rails-web -n rails-app -- bin/rails console
```

### Database Backup

```bash
# Create backup
kubectl exec -it deployment/postgres -n rails-app -- pg_dump -U postgres test_rails_71_app_production > backup.sql

# Restore backup
kubectl exec -i deployment/postgres -n rails-app -- psql -U postgres test_rails_71_app_production < backup.sql
```

## Scaling

### Manual Scaling

```bash
# Scale web servers
kubectl scale deployment rails-web --replicas=5 -n rails-app

# Scale Sidekiq workers
kubectl scale deployment sidekiq --replicas=3 -n rails-app
```

### Cluster Scaling

```bash
# Scale AKS cluster nodes
az aks scale --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --node-count 5
```

### Storage Scaling

```bash
# Expand persistent volume (only increase supported)
kubectl patch pvc postgres-pvc -n rails-app -p '{\"spec\":{\"resources\":{\"requests\":{\"storage\":\"50Gi\"}}}}'
```

## Troubleshooting

### Common Issues

**Pods stuck in Pending state:**
```bash
# Check resource availability
kubectl describe node
kubectl get events -n rails-app --sort-by=.metadata.creationTimestamp
```

**Image pull errors:**
```bash
# Check ACR integration
az aks check-acr --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --acr $ACR_NAME

# Recreate ACR secret
./deploy-aks.sh secrets
```

**Database connection issues:**
```bash
# Check PostgreSQL pod logs
kubectl logs deployment/postgres -n rails-app

# Test database connectivity
kubectl exec -it deployment/rails-web -n rails-app -- bin/rails db:migrate:status
```

**SSL certificate issues:**
```bash
# Check cert-manager status
kubectl get certificates -n rails-app
kubectl describe certificate rails-app-tls -n rails-app

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager
```

### Performance Issues

**High memory usage:**
```bash
# Check resource usage
kubectl top pods -n rails-app

# Adjust resource limits in deployment files
# Edit k8s/base/rails-app.yaml, postgres.yaml, etc.
```

**Slow response times:**
```bash
# Check HPA status
kubectl get hpa -n rails-app

# Review ingress logs for bottlenecks
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
```

## CI/CD Integration

### GitHub Actions Example

```yaml
# .github/workflows/deploy-aks.yml
name: Deploy to AKS
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - name: Login to Azure
      uses: azure/login@v1
      with:
        creds: ${{ secrets.AZURE_CREDENTIALS }}
    - name: Deploy to AKS
      run: ./deploy-aks.sh deploy
      env:
        RESOURCE_GROUP: ${{ secrets.RESOURCE_GROUP }}
        CLUSTER_NAME: ${{ secrets.CLUSTER_NAME }}
        ACR_NAME: ${{ secrets.ACR_NAME }}
```

### Azure DevOps Integration

Create build and release pipelines using the Azure DevOps Kubernetes integration with the provided deployment scripts.

## Cost Optimization

### Resource Optimization
- Use Azure Reserved Instances for predictable workloads
- Implement cluster autoscaler for dynamic scaling
- Use spot instances for development environments
- Monitor resource usage and adjust limits

### Storage Optimization
- Use appropriate storage classes (Standard vs Premium)
- Implement storage lifecycle policies
- Regular cleanup of unused persistent volumes

## Maintenance

### Regular Tasks
- Update Kubernetes manifests for new application versions
- Monitor resource usage and costs
- Update certificates (handled automatically by cert-manager)
- Review and apply security updates
- Backup critical data regularly

### Updates

```bash
# Update application
./deploy-aks.sh build
kubectl rollout restart deployment/rails-web -n rails-app
kubectl rollout restart deployment/sidekiq -n rails-app

# Update AKS cluster
az aks upgrade --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --kubernetes-version 1.27.0
```

## Support and Monitoring

### Azure Support
- Use Azure Monitor for cluster and application metrics
- Set up alerts for critical issues
- Use Azure Log Analytics for centralized logging

### Application Monitoring
- Integrate with APM tools (New Relic, Datadog, etc.)
- Set up error tracking (Sentry, Bugsnag, etc.)
- Implement custom health check endpoints

For issues specific to the Rails application, refer to the main application documentation and the production deployment guide.
