# =============================================================================
# Multi-stage Dockerfile for Production React + Express App
# =============================================================================

# ------------ Stage 1: Build React App --------------
FROM node:20-alpine AS builder

WORKDIR /app

# Install build dependencies and build assets
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# ------------ Stage 2: Production Server ------------
FROM node:20-alpine AS production

# Security: non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

WORKDIR /app

# Install only production server deps
COPY package*.json ./
RUN npm install --omit=dev express compression helmet && npm cache clean --force

# App code
COPY server ./server
COPY --from=builder /app/build ./build

# File ownership
RUN chown -R nodejs:nodejs /app

USER nodejs

ENV NODE_ENV=production PORT=3000 HOST=0.0.0.0 SERVICE_NAME=ecommerce-frontend SERVICE_VERSION=1.0.0

EXPOSE 3000

# ---- Health check (no curl needed, just node) ----
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000/health',r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))"

CMD ["node", "server/index.js"]