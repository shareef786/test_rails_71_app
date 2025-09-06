# GitHub Actions CI/CD Setup Guide

This guide explains how to set up the GitHub Actions workflow for automatic deployment to Azure Kubernetes Service (AKS) when code is pushed to the main branch.

## Workflow Overview

The GitHub Actions workflow includes three jobs:

1. **Test**: Runs tests and security audits on every push and pull request
2. **Deploy**: Builds and deploys to AKS (only on main branch pushes)
3. **Cleanup**: Cleans up old Docker images after successful deployment

## Prerequisites

### Required GitHub Secrets

You need to configure the following secrets in your GitHub repository settings:

#### Azure Credentials (Required)
```bash
# Create a service principal for GitHub Actions
az ad sp create-for-rbac --name "github-actions-rails-app" --role contributor \
    --scopes /subscriptions/{subscription-id}/resourceGroups/{resource-group-name} \
    --sdk-auth

# This will output JSON - copy it to GitHub secret: AZURE_CREDENTIALS
```

#### Application Secrets (Required)
- `SECRET_KEY_BASE` - Rails secret key base (generate with `rails secret`)
- `RAILS_MASTER_KEY` - Rails master key (copy from `config/master.key`)
- `POSTGRES_PASSWORD` - PostgreSQL password (generate secure password)
- `AZURE_ACR_NAME` - Azure Container Registry name (must be globally unique)

#### Azure Configuration (Optional - defaults provided)
- `AZURE_RESOURCE_GROUP` - Resource group name (default: 'rails-app-rg')
- `AZURE_CLUSTER_NAME` - AKS cluster name (default: 'rails-app-aks')
- `AZURE_LOCATION` - Azure location (default: 'East US')

#### Domain Configuration (Optional)
- `DOMAIN_NAME` - Your domain name for ingress (e.g., 'myapp.com')
- `LETSENCRYPT_EMAIL` - Email for Let's Encrypt certificates

## Setup Steps

### 1. Create Azure Service Principal

```bash
# Login to Azure
az login

# Set your subscription
az account set --subscription "your-subscription-id"

# Create service principal (replace {subscription-id} with your actual subscription ID)
az ad sp create-for-rbac --name "github-actions-rails-app" \
    --role contributor \
    --scopes /subscriptions/{subscription-id} \
    --sdk-auth
```

Copy the JSON output and add it as `AZURE_CREDENTIALS` secret in GitHub.

### 2. Generate Rails Secrets

```bash
# Generate secret key base
rails secret

# Get master key (if it exists)
cat config/master.key

# Generate secure database password
openssl rand -base64 32
```

### 3. Configure GitHub Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions, and add:

**Required secrets:**
- `AZURE_CREDENTIALS` - JSON output from service principal creation
- `SECRET_KEY_BASE` - Generated Rails secret key
- `RAILS_MASTER_KEY` - Rails master key
- `POSTGRES_PASSWORD` - Secure database password
- `AZURE_ACR_NAME` - Unique ACR name (e.g., `railsappacr12345`)

**Optional secrets:**
- `DOMAIN_NAME` - Your domain name
- `LETSENCRYPT_EMAIL` - Your email for SSL certificates
- `AZURE_RESOURCE_GROUP` - Custom resource group name
- `AZURE_CLUSTER_NAME` - Custom AKS cluster name
- `AZURE_LOCATION` - Preferred Azure location

### 4. Configure Branch Protection (Optional)

To ensure tests pass before deployment:

1. Go to Settings → Branches
2. Add branch protection rule for `main`
3. Check "Require status checks to pass before merging"
4. Select the "test" check from your workflow

## Workflow Features

### 🧪 **Comprehensive Testing**
- Runs on every push and pull request
- Tests with PostgreSQL and Redis services
- Runs both unit tests and system tests
- Security audits with bundler-audit and npm audit
- Prevents deployment if tests fail

### 🚀 **Automated Deployment**
- Only deploys on pushes to main branch
- Creates Azure resources if they don't exist
- Builds and pushes Docker images to ACR
- Sets up NGINX Ingress Controller and Cert-Manager
- Deploys all services (PostgreSQL, Redis, Elasticsearch, Kafka)
- Runs database migrations automatically
- Provides deployment status and external IP

### 🔧 **Infrastructure as Code**
- Creates AKS cluster with autoscaling (2-10 nodes)
- Attaches ACR to AKS cluster
- Sets up monitoring and logging
- Configures SSL certificates automatically
- Network policies and security headers

### 🧹 **Cleanup**
- Removes old Docker images to save storage
- Keeps deployment history organized

## Workflow Triggers

The workflow runs on:
- **Push to main branch**: Runs tests and deploys
- **Pull requests to main**: Runs tests only
- **Manual trigger**: Can be triggered manually from Actions tab

## Monitoring Deployment

### View Workflow Status
- Go to Actions tab in your GitHub repository
- Click on the latest workflow run
- Monitor progress in real-time

### Check Deployment Logs
```bash
# View workflow logs in GitHub Actions
# Or connect to AKS and check pods
kubectl get pods -n rails-app
kubectl logs -f deployment/rails-web -n rails-app
```

### Get Application URL
The workflow will output the external IP address. You can also get it manually:
```bash
kubectl get svc ingress-nginx-controller -n ingress-nginx
```

## Customization

### Modify Resource Specifications
Edit `k8s/base/*.yaml` files to adjust:
- Resource limits (CPU/Memory)
- Storage sizes
- Replica counts
- Environment variables

### Update Workflow Configuration
Edit `.github/workflows/deploy-aks.yml` to:
- Change Azure VM sizes
- Modify timeout values
- Add additional deployment steps
- Configure different environments

### Environment-Specific Deployments
Create separate workflows for different environments:
- `.github/workflows/deploy-staging.yml`
- `.github/workflows/deploy-production.yml`

## Troubleshooting

### Common Issues

**Azure Authentication Failed:**
- Verify AZURE_CREDENTIALS secret is correct JSON
- Ensure service principal has correct permissions
- Check subscription ID in the credentials

**ACR Name Already Exists:**
- ACR names must be globally unique
- Try adding random numbers/letters to AZURE_ACR_NAME
- Check if name is available: `az acr check-name --name yourname`

**Deployment Timeouts:**
- AKS cluster creation can take 10-15 minutes
- Increase timeout values in workflow if needed
- Monitor Azure portal for resource creation status

**Database Migration Failures:**
- Check PostgreSQL pod logs
- Ensure database is ready before migrations
- Verify connection strings and secrets

**SSL Certificate Issues:**
- Ensure domain is properly configured
- Check cert-manager logs
- Verify DNS points to LoadBalancer IP

### Debug Commands

```bash
# Check workflow logs in GitHub Actions UI

# Or connect to AKS cluster locally:
az aks get-credentials --resource-group rails-app-rg --name rails-app-aks

# Check pod status
kubectl get pods -n rails-app

# View logs
kubectl logs deployment/rails-web -n rails-app

# Check ingress
kubectl get ingress -n rails-app

# Get external IP
kubectl get svc ingress-nginx-controller -n ingress-nginx
```

## Security Considerations

### Secrets Management
- All sensitive data stored in GitHub secrets
- Secrets are encrypted and only available during workflow execution
- Service principal has minimum required permissions

### Network Security
- Network policies restrict pod-to-pod communication
- Ingress controller with security headers
- SSL/TLS encryption with Let's Encrypt

### Image Security
- Multi-stage Docker builds for smaller attack surface
- Regular security audits in CI pipeline
- Automatic cleanup of old images

## Maintenance

### Regular Tasks
- Update dependencies in Gemfile and package.json
- Monitor resource usage and costs in Azure portal
- Review and rotate secrets periodically
- Update Kubernetes versions when available

### Scaling
The workflow creates an AKS cluster with autoscaling enabled:
- Minimum 2 nodes, maximum 10 nodes
- Horizontal Pod Autoscaler for application pods
- Adjust limits in workflow file as needed

## Cost Optimization

### Development Environment
For development/testing, consider:
- Using smaller VM sizes (Standard_B2s)
- Reducing node count to 1
- Using standard storage instead of premium
- Implementing cluster scheduling (start/stop)

### Production Optimization
- Use Azure Reserved Instances for predictable savings
- Monitor resource usage with Azure Monitor
- Implement pod resource requests/limits
- Regular cleanup of unused resources
