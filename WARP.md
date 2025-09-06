# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Architecture Overview

This is a Rails 7.1.5 application built with Ruby 3.4.5. The application demonstrates a modern Rails stack with integrated search capabilities and background job processing.

### Key Components

- **Database**: PostgreSQL with environment-configurable connection settings
- **Search**: Elasticsearch integration via `elasticsearch-model` gem for the Book model
- **Background Jobs**: Sidekiq for background job processing with Redis
- **Message Streaming**: Kafka integration using `ruby-kafka` gem
- **Frontend**: Traditional Rails views with Hotwire (Turbo + Stimulus) for interactivity
- **Assets**: Importmap for JavaScript modules, traditional asset pipeline via Sprockets

### Application Structure

The application centers around a `Book` resource with full CRUD operations:
- **Models**: `Book` model with Elasticsearch integration for search functionality
- **Controllers**: Standard Rails RESTful controllers with JSON API support
- **Views**: ERB templates with Hotwire integration
- **Routes**: RESTful routes for books, Sidekiq web UI mounted at `/sidekiq`, health check at `/up`

## Development Commands

### Setup and Installation
```bash
# Initial setup (installs dependencies, prepares database, clears logs)
bin/setup

# Install/update dependencies only
bundle install
```

### Database Operations
```bash
# Create databases
bin/rails db:create

# Run migrations
bin/rails db:migrate

# Prepare database (setup if new, migrate if existing)
bin/rails db:prepare

# Reset database (drop, create, migrate, seed)
bin/rails db:reset

# Load seed data
bin/rails db:seed

# Check migration status
bin/rails db:migrate:status
```

### Running the Application
```bash
# Start Rails server (development)
bin/rails server

# Start with specific port
bin/rails server -p 4000

# Start Rails console
bin/rails console

# Background jobs (Sidekiq) - run in separate terminal
bundle exec sidekiq
```

### Testing
```bash
# Run all tests
bin/rails test

# Run specific test file
bin/rails test test/models/book_test.rb

# Run system tests
bin/rails test:system

# Reset test database and run tests
bin/rails test:db
```

### Asset Management
```bash
# Precompile assets for production
bin/rails assets:precompile

# Clean old compiled assets
bin/rails assets:clean

# Remove all compiled assets
bin/rails assets:clobber
```

### Development Utilities
```bash
# Generate new migration
bin/rails generate migration MigrationName

# Generate new controller
bin/rails generate controller ControllerName

# Generate scaffold
bin/rails generate scaffold ModelName field:type

# Clear logs
bin/rails log:clear

# Clear tmp files
bin/rails tmp:clear

# Check code statistics
bin/rails stats

# Check Zeitwerk loading compatibility
bin/rails zeitwerk:check
```

## Docker Usage

The application includes Docker support:
```bash
# Build Docker image
docker build -t test-rails-app .

# Run with Docker (requires environment variables for database, Redis, etc.)
docker run -p 3000:3000 test-rails-app
```

## External Dependencies

### Required Services
- **PostgreSQL**: Database server
- **Redis**: Required for Sidekiq background jobs
- **Elasticsearch**: Required for Book model search functionality

### Environment Variables
The application expects these environment variables for external service connections:
- `POSTGRES_USER` (defaults to "postgres")
- `POSTGRES_PASSWORD` (defaults to empty)
- `POSTGRES_HOST` (defaults to "localhost")
- `RAILS_MAX_THREADS` (defaults to 5, used for database pool size)

## Code Organization

### Models
- `ApplicationRecord`: Base class for all models
- `Book`: Main domain model with Elasticsearch integration for search capabilities

### Controllers
- `ApplicationController`: Base controller with common functionality
- `BooksController`: RESTful controller supporting both HTML and JSON responses

### Configuration
- Database configuration is environment-aware with sensible defaults
- Elasticsearch settings are configured directly in the Book model
- Sidekiq web interface is mounted and accessible in development

## Testing Strategy

- Uses Rails' built-in test framework with parallel test execution enabled
- Includes unit tests (`test/models/`), controller tests (`test/controllers/`), and system tests (`test/system/`)
- Test database is automatically prepared when running tests
