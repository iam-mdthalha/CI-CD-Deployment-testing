'use strict';

const express = require('express');
const router = express.Router();

// =============================================================================
// Environment Variables
// =============================================================================
const SERVICE_NAME = process.env.SERVICE_NAME || 'ecommerce-frontend';
const SERVICE_VERSION = process.env.SERVICE_VERSION || '1.0.0';
const NODE_ENV = process.env.NODE_ENV || 'production';

// =============================================================================
// Health Check State
// =============================================================================
const startTime = Date.now();

// =============================================================================
// GET /health - Main Health Check Endpoint
// =============================================================================
router.get('/', (req, res) => {
  const uptime = Math.floor((Date.now() - startTime) / 1000);
  const memoryUsage = process.memoryUsage();

  res.status(200).json({
    status: 'healthy',
    service: SERVICE_NAME,
    version: SERVICE_VERSION,
    environment: NODE_ENV,
    timestamp: new Date().toISOString(),
    uptime:  {
      seconds: uptime,
      formatted: formatUptime(uptime)
    },
    memory: {
      heapUsed: formatBytes(memoryUsage.heapUsed),
      heapTotal: formatBytes(memoryUsage.heapTotal),
      rss: formatBytes(memoryUsage. rss)
    }
  });
});

// =============================================================================
// GET /health/live - Liveness Probe
// =============================================================================
router.get('/live', (req, res) => {
  res.status(200).json({
    status: 'alive',
    timestamp: new Date().toISOString()
  });
});

// =============================================================================
// GET /health/ready - Readiness Probe
// =============================================================================
router. get('/ready', (req, res) => {
  res. status(200).json({
    status:  'ready',
    timestamp: new Date().toISOString()
  });
});

// =============================================================================
// Helper Functions
// =============================================================================
function formatUptime(seconds) {
  const days = Math.floor(seconds / 86400);
  const hours = Math.floor((seconds % 86400) / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const secs = seconds % 60;

  const parts = [];
  if (days > 0) parts.push(`${days}d`);
  if (hours > 0) parts.push(`${hours}h`);
  if (minutes > 0) parts.push(`${minutes}m`);
  parts.push(`${secs}s`);

  return parts. join(' ');
}

function formatBytes(bytes) {
  const mb = bytes / 1024 / 1024;
  return `${mb.toFixed(2)} MB`;
}

module.exports = router;