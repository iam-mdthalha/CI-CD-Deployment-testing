#!/bin/bash
set -e

# ===========================================
# CI-CD Deployment Project Structure Script
# ===========================================
# This script ONLY creates folders and files
# No git initialization or git commands
# ===========================================

echo "🚀 Creating CI-CD-Deployment-testing project structure..."

# -------------------------------
# GitHub configuration
# -------------------------------
mkdir -p .github/workflows
touch .github/workflows/ci.yml
touch .github/workflows/cd.yml
touch .github/PULL_REQUEST_TEMPLATE.md
touch .github/CODEOWNERS

# -------------------------------
# Frontend source
# -------------------------------


touch ecommerce-frontend/package.json
touch ecommerce-frontend/package-lock.json
touch ecommerce-frontend/Dockerfile
touch ecommerce-frontend/.dockerignore
touch ecommerce-frontend/.env.example
# -------------------------------
# Scripts
# -------------------------------
mkdir -p scripts
touch scripts/deploy.sh
touch scripts/rollback.sh
touch scripts/health-check.sh
touch scripts/switch-traffic.sh
touch scripts/setup-server.sh

# -------------------------------
# Nginx
# -------------------------------
mkdir -p nginx
touch nginx/nginx.conf
touch nginx/app.conf

# -------------------------------
# Documentation
# -------------------------------
mkdir -p docs
touch docs/ARCHITECTURE.md
touch docs/BRANCHING.md
touch docs/DEPLOYMENT.md
touch docs/ROLLBACK.md

# -------------------------------
# Root-level files
# -------------------------------
touch .gitignore
touch .env.example
touch docker-compose.yml
touch docker-compose.blue.yml
touch docker-compose.green.yml
touch README.md

echo "✅ Project structure created successfully."