#!/bin/bash

# Azure Subscription Health Check Script
# This script checks if your Azure subscription is properly configured for ACR and AKS

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check if Azure CLI is installed
check_azure_cli() {
    log_info "Checking Azure CLI installation..."
    
    if ! command -v az >/dev/null 2>&1; then
        log_error "Azure CLI is not installed"
        echo "Please install Azure CLI from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        exit 1
    fi
    
    log_success "Azure CLI is installed"
    az --version | head -1
}

# Check if user is logged in
check_azure_login() {
    log_info "Checking Azure login status..."
    
    if ! az account show >/dev/null 2>&1; then
        log_error "Not logged in to Azure"
        echo "Please run: az login"
        exit 1
    fi
    
    local account_name=$(az account show --query name -o tsv)
    local subscription_id=$(az account show --query id -o tsv)
    
    log_success "Logged in to Azure"
    echo "  Account: $account_name"
    echo "  Subscription ID: $subscription_id"
}

# Check resource provider registration
check_resource_providers() {
    log_info "Checking Azure resource provider registration..."
    
    local providers=(
        "Microsoft.ContainerRegistry"
        "Microsoft.ContainerService"
        "Microsoft.Compute"
        "Microsoft.Network"
        "Microsoft.Storage"
    )
    
    local needs_registration=false
    
    for provider in "${providers[@]}"; do
        local state=$(az provider show --namespace "$provider" --query registrationState -o tsv 2>/dev/null || echo "Unknown")
        
        case $state in
            "Registered")
                log_success "$provider is registered"
                ;;
            "Registering")
                log_warning "$provider is currently registering"
                needs_registration=true
                ;;
            "NotRegistered"|"Unregistered")
                log_error "$provider is not registered"
                needs_registration=true
                ;;
            *)
                log_warning "$provider status is unknown: $state"
                needs_registration=true
                ;;
        esac
    done
    
    if [ "$needs_registration" = true ]; then
        echo ""
        log_warning "Some resource providers need to be registered"
        echo "You can register them by running this script with the --fix flag:"
        echo "  $0 --fix"
        echo ""
        echo "Or register them manually:"
        for provider in "${providers[@]}"; do
            echo "  az provider register --namespace $provider"
        done
        return 1
    fi
    
    log_success "All required resource providers are registered"
}

# Register resource providers
register_providers() {
    log_info "Registering Azure resource providers..."
    
    local providers=(
        "Microsoft.ContainerRegistry"
        "Microsoft.ContainerService"
        "Microsoft.Compute"
        "Microsoft.Network"
        "Microsoft.Storage"
    )
    
    for provider in "${providers[@]}"; do
        log_info "Registering $provider..."
        az provider register --namespace "$provider"
    done
    
    log_info "Registration initiated. Checking status..."
    
    # Wait for registration to complete (with timeout)
    local timeout=300
    local elapsed=0
    local all_registered=false
    
    while [ $elapsed -lt $timeout ] && [ "$all_registered" = false ]; do
        all_registered=true
        
        for provider in "${providers[@]}"; do
            local state=$(az provider show --namespace "$provider" --query registrationState -o tsv 2>/dev/null || echo "Unknown")
            
            if [ "$state" != "Registered" ]; then
                all_registered=false
                log_info "Waiting for $provider (currently: $state)..."
                break
            fi
        done
        
        if [ "$all_registered" = true ]; then
            break
        fi
        
        sleep 10
        elapsed=$((elapsed + 10))
    done
    
    if [ "$all_registered" = true ]; then
        log_success "All resource providers are now registered"
    else
        log_warning "Resource provider registration may still be in progress"
        log_info "You can check the status later by running: $0"
    fi
}

# Check subscription limits
check_subscription_limits() {
    log_info "Checking subscription limits and quotas..."
    
    # Check compute quotas
    local location="${LOCATION:-eastus}"
    
    # Check if we can create resources in the specified location
    local available_locations=$(az account list-locations --query "[].name" -o tsv | tr '\n' ' ')
    if [[ " $available_locations " =~ " $location " ]]; then
        log_success "Location '$location' is available"
    else
        log_warning "Location '$location' may not be available"
        echo "Available locations: $available_locations"
    fi
    
    # Try to get compute usage (this may fail for some subscription types)
    if az vm list-usage --location "$location" >/dev/null 2>&1; then
        local core_usage=$(az vm list-usage --location "$location" --query "[?localName=='Total Regional vCPUs'].{current:currentValue,limit:limit}" -o tsv 2>/dev/null)
        if [ -n "$core_usage" ]; then
            echo "$core_usage" | while read current limit; do
                log_info "vCPU usage in $location: $current/$limit"
                if [ "$current" -ge "$limit" ]; then
                    log_error "vCPU limit reached in $location"
                fi
            done
        fi
    else
        log_info "Unable to check compute quotas (may require elevated permissions)"
    fi
}

# Main execution
main() {
    echo "========================================="
    echo "Azure Subscription Health Check"
    echo "========================================="
    echo ""
    
    # Parse command line arguments
    if [ "$1" = "--fix" ] || [ "$1" = "-f" ]; then
        FIX_ISSUES=true
    else
        FIX_ISSUES=false
    fi
    
    # Run checks
    check_azure_cli
    echo ""
    
    check_azure_login
    echo ""
    
    if [ "$FIX_ISSUES" = true ]; then
        register_providers
        echo ""
    else
        if ! check_resource_providers; then
            echo ""
            echo "Run '$0 --fix' to automatically register the required providers"
            exit 1
        fi
        echo ""
    fi
    
    check_subscription_limits
    echo ""
    
    log_success "Azure subscription health check completed"
    
    if [ "$FIX_ISSUES" = false ]; then
        echo ""
        echo "Your Azure subscription appears to be ready for ACR and AKS deployment."
        echo "You can now run the deployment script:"
        echo "  ./deploy-aks.sh deploy"
    fi
}

# Show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "OPTIONS:"
    echo "  --fix, -f    Automatically register required Azure resource providers"
    echo "  --help, -h   Show this help message"
    echo ""
    echo "EXAMPLES:"
    echo "  $0           Check subscription health"
    echo "  $0 --fix     Check and fix resource provider registration"
}

# Handle command line arguments
case "${1:-}" in
    "--help"|"-h")
        show_usage
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac
