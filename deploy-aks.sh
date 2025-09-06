#!/bin/bash

# AKS Deployment Script for Rails Application
# This script handles deployment to Azure Kubernetes Service

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
RESOURCE_GROUP="${RESOURCE_GROUP:-rails-app-rg}"
CLUSTER_NAME="${CLUSTER_NAME:-rails-app-aks}"
LOCATION="${LOCATION:-East US}"
ACR_NAME="${ACR_NAME:-railsappacr}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
KUBECTL_CONTEXT=""

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_dependencies() {
    log_info "Checking dependencies..."
    
    command -v az >/dev/null 2>&1 || { log_error "Azure CLI is required but not installed. Aborting."; exit 1; }
    command -v kubectl >/dev/null 2>&1 || { log_error "kubectl is required but not installed. Aborting."; exit 1; }
    command -v docker >/dev/null 2>&1 || { log_error "Docker is required but not installed. Aborting."; exit 1; }
    
    log_success "All dependencies are installed"
}

setup_azure_resources() {
    log_info "Setting up Azure resources..."
    
    # Create resource group
    az group create --name $RESOURCE_GROUP --location "$LOCATION" || true
    
    # Create ACR
    az acr create \
        --resource-group $RESOURCE_GROUP \
        --name $ACR_NAME \
        --sku Standard \
        --admin-enabled true || true
    
    # Create AKS cluster
    if ! az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME >/dev/null 2>&1; then
        log_info "Creating AKS cluster (this may take 10-15 minutes)..."
        az aks create \
            --resource-group $RESOURCE_GROUP \
            --name $CLUSTER_NAME \
            --node-count 3 \
            --node-vm-size Standard_D2s_v3 \
            --enable-addons monitoring,http_application_routing \
            --attach-acr $ACR_NAME \
            --generate-ssh-keys
    else
        log_info "AKS cluster already exists"
    fi
    
    # Get AKS credentials
    az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME
    
    log_success "Azure resources configured"
}

build_and_push_image() {
    log_info "Building and pushing Docker image..."
    
    # Get ACR login server
    ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query loginServer --output tsv)
    
    # Login to ACR
    az acr login --name $ACR_NAME
    
    # Build image
    docker build -f Dockerfile.production -t ${ACR_LOGIN_SERVER}/rails-app:${IMAGE_TAG} .
    
    # Push image
    docker push ${ACR_LOGIN_SERVER}/rails-app:${IMAGE_TAG}
    
    log_success "Image built and pushed to ACR"
    
    # Update the image reference in the deployment
    sed -i.bak "s|your-registry.azurecr.io|${ACR_LOGIN_SERVER}|g" k8s/base/rails-app.yaml
    
    log_success "Updated image references in Kubernetes manifests"
}

setup_ingress_controller() {
    log_info "Setting up NGINX Ingress Controller..."
    
    # Add ingress-nginx repository
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo update
    
    # Install or upgrade NGINX Ingress Controller
    helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --create-namespace \
        --set controller.replicaCount=2 \
        --set controller.nodeSelector."kubernetes\.io/os"=linux \
        --set defaultBackend.nodeSelector."kubernetes\.io/os"=linux \
        --set controller.service.type=LoadBalancer
    
    log_success "NGINX Ingress Controller installed"
}

setup_cert_manager() {
    log_info "Setting up Cert-Manager for SSL..."
    
    # Add jetstack repository
    helm repo add jetstack https://charts.jetstack.io
    helm repo update
    
    # Install cert-manager
    helm upgrade --install cert-manager jetstack/cert-manager \
        --namespace cert-manager \
        --create-namespace \
        --version v1.13.0 \
        --set installCRDs=true
    
    log_success "Cert-Manager installed"
}

create_secrets() {
    log_info "Creating Kubernetes secrets..."
    
    # Check if secrets.env exists
    if [ ! -f "secrets.env" ]; then
        log_warning "secrets.env not found. Creating template..."
        cat > secrets.env << EOF
SECRET_KEY_BASE=$(openssl rand -hex 64)
RAILS_MASTER_KEY=$(cat config/master.key 2>/dev/null || echo "CHANGE_ME")
POSTGRES_PASSWORD=$(openssl rand -base64 32)
EOF
        log_warning "Please edit secrets.env with your actual values before deploying"
        exit 1
    fi
    
    # Create namespace
    kubectl apply -f k8s/base/namespace.yaml
    
    # Source the environment file
    source secrets.env
    
    # Create the secrets
    kubectl create secret generic rails-app-secrets \
        --namespace=rails-app \
        --from-literal=SECRET_KEY_BASE="$SECRET_KEY_BASE" \
        --from-literal=RAILS_MASTER_KEY="$RAILS_MASTER_KEY" \
        --from-literal=POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Create ACR secret
    ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query loginServer --output tsv)
    ACR_USERNAME=$(az acr credential show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query username --output tsv)
    ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query passwords[0].value --output tsv)
    
    kubectl create secret docker-registry azure-container-registry \
        --namespace=rails-app \
        --docker-server="$ACR_LOGIN_SERVER" \
        --docker-username="$ACR_USERNAME" \
        --docker-password="$ACR_PASSWORD" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    log_success "Secrets created successfully"
}

deploy_application() {
    log_info "Deploying Rails application to AKS..."
    
    # Apply all Kubernetes manifests
    kubectl apply -k k8s/base/
    
    # Wait for deployments to be ready
    log_info "Waiting for deployments to be ready..."
    kubectl wait --for=condition=available --timeout=600s deployment/postgres -n rails-app
    kubectl wait --for=condition=available --timeout=600s deployment/redis -n rails-app
    kubectl wait --for=condition=available --timeout=600s deployment/elasticsearch -n rails-app
    kubectl wait --for=condition=available --timeout=600s deployment/zookeeper -n rails-app
    kubectl wait --for=condition=available --timeout=600s deployment/kafka -n rails-app
    kubectl wait --for=condition=available --timeout=600s deployment/rails-web -n rails-app
    kubectl wait --for=condition=available --timeout=600s deployment/sidekiq -n rails-app
    
    log_success "Application deployed successfully"
}

get_ingress_ip() {
    log_info "Getting ingress IP address..."
    
    # Wait for LoadBalancer to get external IP
    local timeout=300
    local elapsed=0
    
    while [ $elapsed -lt $timeout ]; do
        EXTERNAL_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
        
        if [ -n "$EXTERNAL_IP" ]; then
            log_success "Application is available at: http://$EXTERNAL_IP"
            log_info "Configure your DNS to point to this IP address"
            break
        fi
        
        log_info "Waiting for LoadBalancer IP... ($elapsed/$timeout seconds)"
        sleep 10
        elapsed=$((elapsed + 10))
    done
    
    if [ -z "$EXTERNAL_IP" ]; then
        log_warning "Could not get external IP. Check LoadBalancer service manually:"
        log_info "kubectl get svc ingress-nginx-controller -n ingress-nginx"
    fi
}

health_check() {
    log_info "Performing health checks..."
    
    # Check pod status
    kubectl get pods -n rails-app
    
    # Check services
    kubectl get svc -n rails-app
    
    # Check ingress
    kubectl get ingress -n rails-app
    
    log_success "Health check completed"
}

cleanup() {
    log_info "Cleaning up resources..."
    
    # Delete the application
    kubectl delete -k k8s/base/ || true
    
    # Delete the AKS cluster (optional)
    read -p "Do you want to delete the AKS cluster? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        az aks delete --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --yes --no-wait
        log_success "AKS cluster deletion initiated"
    fi
    
    # Delete ACR (optional)
    read -p "Do you want to delete the Azure Container Registry? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        az acr delete --resource-group $RESOURCE_GROUP --name $ACR_NAME --yes
        log_success "ACR deleted"
    fi
}

show_status() {
    log_info "Showing application status..."
    kubectl get all -n rails-app
}

show_logs() {
    local service=${1:-rails-web}
    kubectl logs -f deployment/$service -n rails-app
}

# Main execution
case "${1:-deploy}" in
    "setup")
        check_dependencies
        setup_azure_resources
        setup_ingress_controller
        setup_cert_manager
        ;;
    "build")
        check_dependencies
        build_and_push_image
        ;;
    "secrets")
        create_secrets
        ;;
    "deploy")
        check_dependencies
        setup_azure_resources
        build_and_push_image
        setup_ingress_controller
        setup_cert_manager
        create_secrets
        deploy_application
        get_ingress_ip
        health_check
        ;;
    "status")
        show_status
        ;;
    "logs")
        show_logs $2
        ;;
    "health")
        health_check
        ;;
    "ip")
        get_ingress_ip
        ;;
    "cleanup")
        cleanup
        ;;
    *)
        echo "Usage: $0 {setup|build|secrets|deploy|status|logs [service]|health|ip|cleanup}"
        echo ""
        echo "Commands:"
        echo "  setup   - Setup Azure resources (AKS, ACR, Ingress, Cert-Manager)"
        echo "  build   - Build and push Docker image"
        echo "  secrets - Create Kubernetes secrets"
        echo "  deploy  - Full deployment (default)"
        echo "  status  - Show application status"
        echo "  logs    - Show application logs (specify service name)"
        echo "  health  - Run health checks"
        echo "  ip      - Get ingress IP address"
        echo "  cleanup - Clean up resources"
        echo ""
        echo "Environment variables:"
        echo "  RESOURCE_GROUP - Azure resource group name (default: rails-app-rg)"
        echo "  CLUSTER_NAME   - AKS cluster name (default: rails-app-aks)"
        echo "  LOCATION       - Azure location (default: East US)"
        echo "  ACR_NAME       - ACR registry name (default: railsappacr)"
        echo "  IMAGE_TAG      - Docker image tag (default: latest)"
        exit 1
        ;;
esac
