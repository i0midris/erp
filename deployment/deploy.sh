#!/bin/bash

# ERP System Production Deployment Script
# This script handles the complete deployment process with rollback capabilities

set -e  # Exit on any error

# Configuration
PROJECT_NAME="erp-system"
DEPLOYMENT_DIR="/opt/erp"
BACKUP_DIR="/opt/erp/backups"
LOG_DIR="/var/log/erp"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
DEPLOY_TAG="${1:-latest}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_DIR/deploy_$TIMESTAMP.log"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_DIR/deploy_$TIMESTAMP.log"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_DIR/deploy_$TIMESTAMP.log"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_DIR/deploy_$TIMESTAMP.log"
}

# Pre-deployment checks
pre_deployment_checks() {
    log_info "Running pre-deployment checks..."

    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker is not running. Please start Docker service."
        exit 1
    fi

    # Check if Docker Compose is available
    if ! command -v docker-compose >/dev/null 2>&1; then
        log_error "Docker Compose is not installed."
        exit 1
    fi

    # Check available disk space
    local available_space=$(df /opt | tail -1 | awk '{print $4}')
    if [ "$available_space" -lt 5242880 ]; then  # 5GB in KB
        log_error "Insufficient disk space. At least 5GB required."
        exit 1
    fi

    # Check if required environment variables are set
    local required_vars=("DB_USER" "DB_PASSWORD" "JWT_SECRET" "ENCRYPTION_KEY" "REDIS_PASSWORD" "GRAFANA_PASSWORD")
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            log_error "Required environment variable $var is not set."
            exit 1
        fi
    done

    log_success "Pre-deployment checks completed successfully"
}

# Create backup
create_backup() {
    log_info "Creating backup of current deployment..."

    mkdir -p "$BACKUP_DIR/$TIMESTAMP"

    # Backup database
    if docker ps | grep -q erp-db; then
        log_info "Backing up database..."
        docker exec erp-db pg_dump -U "$DB_USER" -d erp_prod > "$BACKUP_DIR/$TIMESTAMP/database.sql" 2>/dev/null || true
    fi

    # Backup configuration files
    if [ -d "$DEPLOYMENT_DIR" ]; then
        cp -r "$DEPLOYMENT_DIR"/* "$BACKUP_DIR/$TIMESTAMP/" 2>/dev/null || true
    fi

    # Backup Docker volumes
    docker run --rm -v erp_db-data:/source -v "$BACKUP_DIR/$TIMESTAMP":/backup alpine tar czf /backup/db-data.tar.gz -C /source . 2>/dev/null || true

    log_success "Backup created at $BACKUP_DIR/$TIMESTAMP"
}

# Pull latest images
pull_images() {
    log_info "Pulling latest Docker images..."

    cd "$DEPLOYMENT_DIR"

    # Pull all images
    docker-compose -f docker-compose.prod.yml pull

    log_success "All images pulled successfully"
}

# Deploy application
deploy_application() {
    log_info "Starting application deployment..."

    cd "$DEPLOYMENT_DIR"

    # Stop existing containers gracefully
    log_info "Stopping existing containers..."
    docker-compose -f docker-compose.prod.yml down --timeout 30

    # Start new containers
    log_info "Starting new containers..."
    docker-compose -f docker-compose.prod.yml up -d

    # Wait for services to be healthy
    log_info "Waiting for services to become healthy..."
    local max_attempts=30
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if docker-compose -f docker-compose.prod.yml ps | grep -q "healthy"; then
            log_success "All services are healthy"
            break
        fi

        if [ $attempt -eq $max_attempts ]; then
            log_error "Services failed to become healthy within timeout"
            rollback_deployment
            exit 1
        fi

        log_info "Waiting for services to be healthy... (attempt $attempt/$max_attempts)"
        sleep 10
        ((attempt++))
    done

    log_success "Application deployed successfully"
}

# Run database migrations
run_migrations() {
    log_info "Running database migrations..."

    # Wait for database to be ready
    local max_attempts=30
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if docker exec erp-db pg_isready -U "$DB_USER" -d erp_prod >/dev/null 2>&1; then
            break
        fi

        if [ $attempt -eq $max_attempts ]; then
            log_error "Database failed to become ready"
            rollback_deployment
            exit 1
        fi

        log_info "Waiting for database... (attempt $attempt/$max_attempts)"
        sleep 5
        ((attempt++))
    done

    # Run migrations if API container has migration commands
    if docker ps | grep -q erp-api; then
        docker exec erp-api npm run migrate 2>/dev/null || log_warn "Migration command not available or failed"
    fi

    log_success "Database migrations completed"
}

# Health checks
perform_health_checks() {
    log_info "Performing health checks..."

    # Check web application
    if curl -f -s http://localhost:80/health >/dev/null 2>&1; then
        log_success "Web application health check passed"
    else
        log_error "Web application health check failed"
        rollback_deployment
        exit 1
    fi

    # Check API
    if curl -f -s http://localhost:3000/health >/dev/null 2>&1; then
        log_success "API health check passed"
    else
        log_error "API health check failed"
        rollback_deployment
        exit 1
    fi

    # Check database connectivity
    if docker exec erp-db pg_isready -U "$DB_USER" -d erp_prod >/dev/null 2>&1; then
        log_success "Database connectivity check passed"
    else
        log_error "Database connectivity check failed"
        rollback_deployment
        exit 1
    fi

    log_success "All health checks passed"
}

# Rollback deployment
rollback_deployment() {
    log_error "Deployment failed. Initiating rollback..."

    cd "$DEPLOYMENT_DIR"

    # Stop current deployment
    docker-compose -f docker-compose.prod.yml down

    # Find latest backup
    local latest_backup=$(ls -td "$BACKUP_DIR"/*/ | head -1)

    if [ -n "$latest_backup" ] && [ -d "$latest_backup" ]; then
        log_info "Rolling back to backup: $latest_backup"

        # Restore database if backup exists
        if [ -f "$latest_backup/database.sql" ]; then
            log_info "Restoring database..."
            docker exec -i erp-db psql -U "$DB_USER" -d erp_prod < "$latest_backup/database.sql" 2>/dev/null || true
        fi

        # Restore configuration files
        if [ -d "$latest_backup/config" ]; then
            cp -r "$latest_backup/config"/* "$DEPLOYMENT_DIR/" 2>/dev/null || true
        fi

        # Restart services
        docker-compose -f docker-compose.prod.yml up -d

        log_success "Rollback completed successfully"
    else
        log_error "No backup found for rollback"
        exit 1
    fi
}

# Post-deployment tasks
post_deployment_tasks() {
    log_info "Running post-deployment tasks..."

    # Clean up old backups (keep last 10)
    log_info "Cleaning up old backups..."
    ls -td "$BACKUP_DIR"/*/ | tail -n +11 | xargs -r rm -rf

    # Update monitoring configuration
    log_info "Updating monitoring configuration..."
    curl -X POST http://localhost:9090/-/reload 2>/dev/null || log_warn "Failed to reload Prometheus configuration"

    # Send deployment notification
    send_notification "Deployment completed successfully" "ERP System v$DEPLOY_TAG deployed to production"

    log_success "Post-deployment tasks completed"
}

# Send notification
send_notification() {
    local subject="$1"
    local message="$2"

    # Send email notification (requires mail command or external service)
    if command -v mail >/dev/null 2>&1; then
        echo "$message" | mail -s "$subject" admin@yourcompany.com 2>/dev/null || true
    fi

    # Log notification
    log_info "NOTIFICATION: $subject - $message"
}

# Main deployment function
main() {
    log_info "Starting ERP System deployment (Tag: $DEPLOY_TAG)"

    # Create necessary directories
    mkdir -p "$DEPLOYMENT_DIR" "$BACKUP_DIR" "$LOG_DIR"

    # Run deployment steps
    pre_deployment_checks
    create_backup
    pull_images
    deploy_application
    run_migrations
    perform_health_checks
    post_deployment_tasks

    log_success "🎉 ERP System deployment completed successfully!"
    log_info "Application is now running at:"
    log_info "  - Web: http://your-domain.com"
    log_info "  - API: http://your-domain.com:3000"
    log_info "  - Monitoring: http://your-domain.com:9090"
    log_info "  - Logs: http://your-domain.com:5601"
}

# Handle script arguments
case "${2:-}" in
    "rollback")
        log_info "Manual rollback requested"
        rollback_deployment
        ;;
    "backup")
        log_info "Manual backup requested"
        create_backup
        ;;
    "health-check")
        log_info "Manual health check requested"
        perform_health_checks
        ;;
    *)
        main
        ;;
esac