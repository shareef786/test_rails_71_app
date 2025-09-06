#!/bin/bash

# GitHub Actions Secrets Setup Script
# This script helps generate the required secrets for the GitHub Actions workflow

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

echo "🚀 GitHub Actions Secrets Setup for AKS Deployment"
echo "=================================================="

# Check if required tools are installed
log_info "Checking required tools..."

command -v az >/dev/null 2>&1 || { log_error "Azure CLI is required but not installed. Please install it first."; exit 1; }
command -v openssl >/dev/null 2>&1 || { log_error "OpenSSL is required but not installed."; exit 1; }

log_success "All required tools are available"

# Generate Rails secrets
log_info "Generating Rails application secrets..."

# Generate SECRET_KEY_BASE
if [ ! -f "config/master.key" ]; then
    log_warning "config/master.key not found. You may need to run 'rails new' or 'rails credentials:edit' first"
    RAILS_MASTER_KEY="CHANGE_ME_GENERATE_WITH_RAILS_CREDENTIALS"
else
    RAILS_MASTER_KEY=$(cat config/master.key)
    log_success "RAILS_MASTER_KEY loaded from config/master.key"
fi

SECRET_KEY_BASE=$(openssl rand -hex 64)
POSTGRES_PASSWORD=$(openssl rand -base64 32)

log_success "Application secrets generated"

# Get Azure subscription info
log_info "Getting Azure subscription information..."
az login --only-show-errors >/dev/null 2>&1 || { log_error "Failed to login to Azure"; exit 1; }

SUBSCRIPTION_ID=$(az account show --query id --output tsv)
SUBSCRIPTION_NAME=$(az account show --query name --output tsv)

log_success "Connected to Azure subscription: $SUBSCRIPTION_NAME"

# Get Azure Container Registry name
log_info "Azure Container Registry name must be globally unique"
read -p "Enter your desired ACR name (lowercase, alphanumeric only): " ACR_NAME

if [ -z "$ACR_NAME" ]; then
    ACR_NAME="railsappacr$(date +%s)"
    log_warning "No ACR name provided, using: $ACR_NAME"
fi

# Check if ACR name is available
log_info "Checking if ACR name '$ACR_NAME' is available..."
ACR_CHECK=$(az acr check-name --name $ACR_NAME --query nameAvailable --output tsv)

if [ "$ACR_CHECK" != "true" ]; then
    log_error "ACR name '$ACR_NAME' is not available. Please try another name."
    exit 1
fi

log_success "ACR name '$ACR_NAME' is available"

# Get resource group name (optional)
read -p "Enter resource group name (press Enter for default: rails-app-rg): " RESOURCE_GROUP
RESOURCE_GROUP=${RESOURCE_GROUP:-rails-app-rg}

# Get cluster name (optional)  
read -p "Enter AKS cluster name (press Enter for default: rails-app-aks): " CLUSTER_NAME
CLUSTER_NAME=${CLUSTER_NAME:-rails-app-aks}

# Get location (optional)
read -p "Enter Azure location (press Enter for default: East US): " LOCATION  
LOCATION=${LOCATION:-"East US"}

# Create service principal
log_info "Creating Azure service principal for GitHub Actions..."

SERVICE_PRINCIPAL_NAME="github-actions-rails-app-$(date +%s)"

# Create service principal with contributor role for the subscription
AZURE_CREDENTIALS=$(az ad sp create-for-rbac \
    --name "$SERVICE_PRINCIPAL_NAME" \
    --role contributor \
    --scopes "/subscriptions/$SUBSCRIPTION_ID" \
    --sdk-auth)

if [ $? -eq 0 ]; then
    log_success "Service principal created successfully"
else
    log_error "Failed to create service principal"
    exit 1
fi

# Get domain name (optional)
read -p "Enter your domain name for SSL (optional, press Enter to skip): " DOMAIN_NAME

# Get Let's Encrypt email (optional)
if [ -n "$DOMAIN_NAME" ]; then
    read -p "Enter your email for Let's Encrypt SSL certificates: " LETSENCRYPT_EMAIL
fi

# Display the secrets
log_success "🎉 Setup completed! Add the following secrets to your GitHub repository:"
echo ""
echo "Go to: GitHub Repository → Settings → Secrets and variables → Actions"
echo ""

echo -e "${GREEN}Required Secrets:${NC}"
echo "==================="
echo ""
echo "AZURE_CREDENTIALS:"
echo "$AZURE_CREDENTIALS"
echo ""
echo "SECRET_KEY_BASE:"
echo "$SECRET_KEY_BASE"
echo ""
echo "RAILS_MASTER_KEY:"
echo "$RAILS_MASTER_KEY"
echo ""
echo "POSTGRES_PASSWORD:"
echo "$POSTGRES_PASSWORD"
echo ""
echo "AZURE_ACR_NAME:"
echo "$ACR_NAME"
echo ""

echo -e "${BLUE}Optional Secrets (with your custom values):${NC}"
echo "============================================="
echo ""
echo "AZURE_RESOURCE_GROUP:"
echo "$RESOURCE_GROUP"
echo ""
echo "AZURE_CLUSTER_NAME:"
echo "$CLUSTER_NAME"
echo ""
echo "AZURE_LOCATION:"
echo "$LOCATION"
echo ""

if [ -n "$DOMAIN_NAME" ]; then
    echo "DOMAIN_NAME:"
    echo "$DOMAIN_NAME"
    echo ""
fi

if [ -n "$LETSENCRYPT_EMAIL" ]; then
    echo "LETSENCRYPT_EMAIL:"
    echo "$LETSENCRYPT_EMAIL"
    echo ""
fi

# Save to file for reference
SECRETS_FILE="github-secrets.txt"
cat > $SECRETS_FILE << EOF
# GitHub Secrets for AKS Deployment
# Generated on: $(date)

# Required Secrets
AZURE_CREDENTIALS=$AZURE_CREDENTIALS
SECRET_KEY_BASE=$SECRET_KEY_BASE
RAILS_MASTER_KEY=$RAILS_MASTER_KEY
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
AZURE_ACR_NAME=$ACR_NAME

# Optional Secrets
AZURE_RESOURCE_GROUP=$RESOURCE_GROUP
AZURE_CLUSTER_NAME=$CLUSTER_NAME
AZURE_LOCATION=$LOCATION
DOMAIN_NAME=$DOMAIN_NAME
LETSENCRYPT_EMAIL=$LETSENCRYPT_EMAIL
EOF

log_success "Secrets also saved to: $SECRETS_FILE"
log_warning "⚠️  Keep this file secure and delete it after adding secrets to GitHub!"

echo ""
echo -e "${GREEN}Next Steps:${NC}"
echo "1. Copy each secret value and add them to GitHub repository secrets"
echo "2. Push your code to the main branch to trigger the deployment"
echo "3. Monitor the deployment in GitHub Actions tab"
echo "4. Delete the $SECRETS_FILE file for security"

echo ""
echo -e "${BLUE}Service Principal Info:${NC}"
echo "Name: $SERVICE_PRINCIPAL_NAME"
echo "Subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"
echo ""
echo -e "${YELLOW}Note:${NC} You can delete this service principal later if needed:"
echo "az ad sp delete --id \$(az ad sp list --display-name '$SERVICE_PRINCIPAL_NAME' --query '[0].id' -o tsv)"
