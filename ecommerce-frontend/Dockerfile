# =============================================================================
# STAGE 1: Build React Application
# =============================================================================
FROM node:20-alpine AS builder

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install ALL dependencies (including devDependencies for build)
RUN npm ci

# Copy source code
COPY . .

# Build React application
RUN npm run build

# =============================================================================
# STAGE 2: Production Server
# =============================================================================
FROM node:20-alpine AS production

# Set working directory
WORKDIR /app

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Set environment variables
ENV NODE_ENV=production \
    PORT=3000 \
    HOST=0.0.0.0 \
    SERVICE_NAME=ecommerce-frontend \
    SERVICE_VERSION=1.0.0

# Copy package files
COPY package*.json ./

# Install ONLY production server dependencies
RUN npm install --omit=dev express compression helmet && \
    npm cache clean --force

# Copy built React app from builder stage
COPY --from=builder /app/build ./build

# Copy server files
COPY server ./server

# Change ownership to non-root user
RUN chown -R nodejs:nodejs /app

# Switch to non-root user
USER nodejs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000/health', (r) => process.exit(r. statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))"

# Start production server
CMD ["node", "server/index.js"]