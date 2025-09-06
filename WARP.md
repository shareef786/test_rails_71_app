# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Application Overview

This is a Ruby on Rails 7.1.5 application built with Ruby 3.4.5 that demonstrates a production-ready microservices architecture. The application includes:

- **Core Framework**: Rails 7.1.5 with modern features (Hotwire, Turbo, Stimulus)
- **Database**: PostgreSQL with Active Record
- **Background Jobs**: Sidekiq with Redis
- **Search**: Elasticsearch integration (currently mocked for testing)
- **Message Streaming**: Kafka with Zookeeper (currently mocked for testing)
- **Frontend**: Import maps with Stimulus controllers
- **Testing**: Minitest with system tests using Capybara and Selenium

## Common Development Commands

### Local Development
```bash
# Install dependencies
bundle install

# Setup database (first time)
bin/rails db:create db:migrate db:seed

# Run the development server
bin/rails server
# OR use foreman for all services
foreman start

# Run all tests
bin/rails test

# Run specific test file
bin/rails test test/models/book_test.rb

# Run system tests
bin/rails test:system

# Run security audit
bundle exec bundler-audit --update

# Rails console
bin/rails console

# Database console
bin/rails dbconsole

# Run migrations
bin/rails db:migrate

# Rollback migrations
bin/rails db:rollback

# Reset database (destructive)
bin/rails db:reset

# View routes
bin/rails routes

# Generate new migration
bin/rails generate migration CreateNewModel field:type

# Generate controller
bin/rails generate controller ControllerName action1 action2

# Generate model
bin/rails generate model ModelName field:type
```

### Background Jobs (Sidekiq)
```bash
# Start Sidekiq worker
bundle exec sidekiq

# Access Sidekiq web interface (available at /sidekiq when app is running)
# Visit http://localhost:3000/sidekiq
```

### Linting and Code Quality
```bash
# Security audit
bundle exec bundler-audit --update

# Check for outdated gems
bundle outdated
```

## Production Deployment

### Docker Compose (Recommended for production)
```bash
# Deploy to production
./deploy.sh deploy

# Check status
./deploy.sh status

# View logs
./deploy.sh logs

# Create database backup
./deploy.sh backup

# Health checks
./deploy.sh health

# Stop services
./deploy.sh stop

# Restart services
./deploy.sh restart

# Cleanup old images
./deploy.sh cleanup
```

### Azure Kubernetes Service (AKS)
```bash
# Deploy to AKS
./deploy-aks.sh deploy

# Check application status
./deploy-aks.sh status

# View logs
./deploy-aks.sh logs rails-web

# Get ingress IP
./deploy-aks.sh ip

# Cleanup resources
./deploy-aks.sh cleanup
```

## Architecture and Code Organization

### Multi-Service Architecture
The application is designed as a distributed system with these services:

1. **Rails Web Application** (`app/`):
   - Controllers handle HTTP requests
   - Models manage data and business logic
   - Services encapsulate complex operations
   - Jobs handle background processing

2. **Background Processing** (Sidekiq):
   - Jobs are processed asynchronously
   - Redis stores job queues and session data

3. **Data Layer**:
   - PostgreSQL for persistent data
   - Redis for caching and session storage
   - Elasticsearch for search (integration ready)

4. **Message Streaming** (Kafka):
   - Producer/Consumer services for event streaming
   - Currently mocked but production-ready configuration exists

### Service Layer Pattern
Business logic is organized in service objects:
- `app/services/kafka_producer_service.rb` - Handles message publishing
- `app/services/kafka_consumer_service.rb` - Processes incoming messages

These services use a mock implementation during testing/development but have production Kafka integration ready to be enabled.

### Configuration Management
- Environment-specific configs in `config/environments/`
- Service initializers in `config/initializers/`
- Kafka client configured with fallback to mock for testing (`config/initializers/kafka.rb`)
- Database configuration supports multiple environments (`config/database.yml`)

### Containerization Strategy
**Development Container** (`Dockerfile`):
- Optimized for development with debugging tools
- Uses Ruby 3.4.5 slim base image

**Production Container** (`Dockerfile.production`):
- Multi-stage build for smaller image size
- Security-hardened with non-root user
- Optimized asset compilation

### Kubernetes Architecture
The K8s deployment (`k8s/base/`) includes:
- Horizontal Pod Autoscaler for web and worker pods
- Persistent volumes for data services
- ConfigMaps and Secrets for configuration
- Health checks and liveness probes
- Network policies for security

### Testing Strategy
- **Unit Tests**: Models and services (`test/models/`, `test/services/`)
- **Controller Tests**: HTTP endpoint testing (`test/controllers/`)
- **System Tests**: End-to-end browser testing (`test/system/`)
- **Parallel Testing**: Enabled by default (disabled in CI)
- **Service Mocking**: External services (Kafka, Elasticsearch) are mocked in test environment

## Development Workflow

### Local Development Setup
1. Ensure PostgreSQL and Redis are running locally
2. Copy environment files: `cp .env.production.example .env.development`
3. Install dependencies: `bundle install`
4. Setup database: `bin/rails db:setup`
5. Start services: `foreman start` or `bin/rails server`

### External Service Integration
**Kafka Integration**:
- Production configuration ready in `config/initializers/kafka.rb`
- Service classes handle graceful fallback to mock implementations
- Environment variable `KAFKA_BROKERS` configures connection

**Elasticsearch Integration**:
- Model integration ready in `app/models/book.rb`
- Commented out for testing but production-ready
- Environment variable `ELASTICSEARCH_URL` configures connection

### Database Patterns
- Uses standard Active Record migrations
- Single model example: `Book` with title, author, published_on
- Migration versioned with Rails 7.1 conventions
- Database seeding available in `db/seeds.rb`

### Deployment Patterns
**Docker Compose Production**:
- Full stack with all services
- Nginx reverse proxy for SSL termination
- Health checks for all services
- Persistent volumes for data
- Automated backups

**Kubernetes Deployment**:
- Microservices architecture
- Auto-scaling based on CPU/memory
- Azure-specific optimizations (ACR, AKS)
- GitOps-ready with GitHub Actions
- SSL certificates via Let's Encrypt

## Important Files and Directories

### Core Application
- `app/models/book.rb` - Example model with Elasticsearch integration ready
- `app/controllers/books_controller.rb` - RESTful controller example
- `app/services/` - Service objects for external integrations
- `config/routes.rb` - Application routing with Sidekiq web interface

### Configuration
- `config/initializers/kafka.rb` - Kafka client with fallback mechanism
- `config/initializers/elasticsearch.rb` - Elasticsearch configuration
- `config/initializers/sidekiq.rb` - Background job configuration

### Deployment
- `deploy.sh` - Production Docker deployment automation
- `deploy-aks.sh` - Azure Kubernetes Service deployment
- `docker-compose.production.yml` - Full production stack definition
- `k8s/base/` - Kubernetes manifests for all services

### CI/CD
- `.github/workflows/deploy-aks.yml` - Automated AKS deployment pipeline
- `Dockerfile` vs `Dockerfile.production` - Environment-specific optimizations

## Environment-Specific Notes

### Development
- External services (Kafka, Elasticsearch) use mock implementations
- Parallel testing enabled for faster test suite execution
- Foreman process manager coordinates multiple services

### Test
- Services always use mock implementations
- Parallel testing disabled in CI environments
- Comprehensive test coverage for controllers, models, and system interactions

### Production
- All services run in containers with health checks
- Automatic scaling based on demand (K8s HPA)
- SSL termination and security headers
- Monitoring and logging integration ready
- Backup automation for critical data

The application demonstrates modern Rails best practices while maintaining production readiness across multiple deployment environments.

## Troubleshooting

### Azure Deployment Issues

**Azure Container Registry Registration Error**:
```
ERROR: (MissingSubscriptionRegistration) The subscription is not registered to use namespace 'Microsoft.ContainerRegistry'
```

This error occurs when your Azure subscription hasn't registered the required resource providers. To fix this:

```bash
# Check subscription health and fix issues automatically
./scripts/check-azure-subscription.sh --fix

# Or register providers manually
az provider register --namespace Microsoft.ContainerRegistry
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.Compute
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.Storage
```

**Check Azure Subscription Status**:
```bash
# Run health check
./scripts/check-azure-subscription.sh

# Check specific provider registration
az provider show --namespace Microsoft.ContainerRegistry --query registrationState
```

### Common Development Issues

**External Services Not Available**:
- Kafka and Elasticsearch use mock implementations in development/test
- Check `config/initializers/kafka.rb` for fallback behavior
- Uncomment production code when deploying to production environments

**Database Connection Issues**:
```bash
# Check if PostgreSQL is running
pg_isready -h localhost -p 5432

# Reset database if needed
bin/rails db:reset
```

**Sidekiq Jobs Not Processing**:
```bash
# Check Redis connection
redis-cli ping

# Restart Sidekiq worker
bundle exec sidekiq
```
