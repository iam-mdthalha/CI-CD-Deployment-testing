'use strict';

const express = require('express');
const compression = require('compression');
const helmet = require('helmet');
const path = require('path');
const healthRouter = require('./health');

// =============================================================================
// Environment Variables
// =============================================================================
const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || '0.0.0.0';
const NODE_ENV = process.env.NODE_ENV || 'production';
const SERVICE_NAME = process.env.SERVICE_NAME || 'ecommerce-frontend';
const SERVICE_VERSION = process.env.SERVICE_VERSION || '1.0.0';
// =============================================================================
// Express App Initialization
// =============================================================================
const app = express();

// =============================================================================
// Middleware
// =============================================================================

// Security headers (configured for React SPA)
app.use(helmet({
  contentSecurityPolicy: false,
  crossOriginEmbedderPolicy: false
}));

// Compression
app.use(compression());

// =============================================================================
// Health Check Endpoint (REQUIRED - DO NOT REMOVE)
// =============================================================================
app.use('/health', healthRouter);

// =============================================================================
// Serve React Static Build
// =============================================================================
const buildPath = path.join(__dirname, '../build');

// Serve static files from React build
app.use(express.static(buildPath));

// Handle React Router - serve index.html for all non-API routes
app.get('*', (req, res) => {
  res.sendFile(path.join(buildPath, 'index.html'));
});

// =============================================================================
// Error Handler
// =============================================================================
app.use((err, req, res, next) => {
  console.error('Error:', err. message);
  res.status(500).json({
    error:  'Internal Server Error',
    message:  NODE_ENV === 'production' ? 'An error occurred' : err.message
  });
});

// =============================================================================
// Server Start
// =============================================================================
const server = app.listen(PORT, HOST, () => {
  console.log('='. repeat(60));
  console.log(`${SERVICE_NAME} v${SERVICE_VERSION}`);
  console.log('='.repeat(60));
  console.log(`Environment:   ${NODE_ENV}`);
  console.log(`Server:        http://${HOST}:${PORT}`);
  console.log(`Health:       http://${HOST}:${PORT}/health`);
  console.log(`Serving:       ${buildPath}`);
  console.log('='.repeat(60));
});

// =============================================================================
// Graceful Shutdown
// =============================================================================
const shutdown = (signal) => {
  console.log(`\n${signal} received. Shutting down gracefully... `);
  server.close(() => {
    console.log('HTTP server closed.');
    process.exit(0);
  });

  setTimeout(() => {
    console.error('Forcing shutdown after timeout.');
    process.exit(1);
  }, 10000);
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

module.exports = app;