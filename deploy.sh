#!/bin/bash

# Production Deployment Script for Rails Application
# This script handles the complete deployment process using Docker Compose

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
COMPOSE_FILE="docker-compose.production.yml"
ENV_FILE=".env.production"
BACKUP_DIR="./backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

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

# Check if environment file exists
check_environment() {
    if [ ! -f "$ENV_FILE" ]; then
        log_error "Environment file $ENV_FILE not found!"
        log_info "Please copy .env.production.example to .env.production and configure it"
        exit 1
    fi
    
    # Check for required environment variables
    if ! grep -q "SECRET_KEY_BASE=" "$ENV_FILE" || ! grep -q "RAILS_MASTER_KEY=" "$ENV_FILE"; then
        log_error "Missing required environment variables in $ENV_FILE"
        log_info "Make sure SECRET_KEY_BASE and RAILS_MASTER_KEY are set"
        exit 1
    fi
}

# Create backup of current database
backup_database() {
    log_info "Creating database backup..."
    mkdir -p "$BACKUP_DIR"
    
    if docker-compose -f "$COMPOSE_FILE" ps postgres | grep -q "Up"; then
        docker-compose -f "$COMPOSE_FILE" exec -T postgres pg_dump \
            -U "${POSTGRES_USER:-postgres}" \
            test_rails_71_app_production > "$BACKUP_DIR/db_backup_$TIMESTAMP.sql"
        log_success "Database backup created: $BACKUP_DIR/db_backup_$TIMESTAMP.sql"
    else
        log_warning "PostgreSQL container not running, skipping database backup"
    fi
}

# Build and deploy
deploy() {
    log_info "Starting production deployment..."
    
    # Pull latest images
    log_info "Pulling latest base images..."
    docker-compose -f "$COMPOSE_FILE" pull postgres redis elasticsearch zookeeper kafka nginx
    
    # Build Rails application
    log_info "Building Rails application..."
    docker-compose -f "$COMPOSE_FILE" build --no-cache web sidekiq
    
    # Stop existing containers
    log_info "Stopping existing containers..."
    docker-compose -f "$COMPOSE_FILE" down
    
    # Start infrastructure services first
    log_info "Starting infrastructure services..."
    docker-compose -f "$COMPOSE_FILE" up -d postgres redis elasticsearch zookeeper kafka
    
    # Wait for services to be ready
    log_info "Waiting for services to be ready..."
    sleep 30
    
    # Run database migrations
    log_info "Running database migrations..."
    docker-compose -f "$COMPOSE_FILE" run --rm web bin/rails db:migrate
    
    # Start application services
    log_info "Starting application services..."
    docker-compose -f "$COMPOSE_FILE" up -d web sidekiq nginx
    
    log_success "Deployment completed successfully!"
}

# Health check
health_check() {
    log_info "Performing health checks..."
    
    # Wait for services to start
    sleep 10
    
    # Check Rails application
    if curl -f http://localhost/up > /dev/null 2>&1; then
        log_success "Rails application is healthy"
    else
        log_error "Rails application health check failed"
        return 1
    fi
    
    # Check Elasticsearch
    if curl -f http://localhost:9200/_health > /dev/null 2>&1; then
        log_success "Elasticsearch is healthy"
    else
        log_warning "Elasticsearch health check failed"
    fi
    
    # Check Redis
    if docker-compose -f "$COMPOSE_FILE" exec -T redis redis-cli ping | grep -q "PONG"; then
        log_success "Redis is healthy"
    else
        log_warning "Redis health check failed"
    fi
    
    log_success "Health checks completed"
}

# Cleanup old images and containers
cleanup() {
    log_info "Cleaning up old Docker images and containers..."
    docker system prune -f
    docker image prune -f
    log_success "Cleanup completed"
}

# Show logs
show_logs() {
    docker-compose -f "$COMPOSE_FILE" logs -f --tail=100
}

# Show status
show_status() {
    docker-compose -f "$COMPOSE_FILE" ps
}

# Main execution
case "${1:-deploy}" in
    "check")
        check_environment
        log_success "Environment check passed"
        ;;
    "backup")
        check_environment
        backup_database
        ;;
    "deploy")
        check_environment
        backup_database
        deploy
        health_check
        cleanup
        ;;
    "health")
        health_check
        ;;
    "logs")
        show_logs
        ;;
    "status")
        show_status
        ;;
    "stop")
        log_info "Stopping all services..."
        docker-compose -f "$COMPOSE_FILE" down
        log_success "All services stopped"
        ;;
    "restart")
        log_info "Restarting all services..."
        docker-compose -f "$COMPOSE_FILE" restart
        log_success "All services restarted"
        ;;
    "cleanup")
        cleanup
        ;;
    *)
        echo "Usage: $0 {check|backup|deploy|health|logs|status|stop|restart|cleanup}"
        echo ""
        echo "Commands:"
        echo "  check   - Check environment configuration"
        echo "  backup  - Create database backup"
        echo "  deploy  - Full deployment (default)"
        echo "  health  - Run health checks"
        echo "  logs    - Show application logs"
        echo "  status  - Show container status"
        echo "  stop    - Stop all services"
        echo "  restart - Restart all services"
        echo "  cleanup - Clean up old Docker images"
        exit 1
        ;;
esac
