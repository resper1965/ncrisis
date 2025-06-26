/**
 * n.crisis Server Entry Point
 * Clean server implementation for production deployment
 */

import NCrisisApp from './app';

const app = new NCrisisApp();

// Graceful shutdown handling
process.on('SIGTERM', async () => {
  console.log('🛑 Received SIGTERM, shutting down gracefully...');
  await app.stop();
  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('🛑 Received SIGINT, shutting down gracefully...');
  await app.stop();
  process.exit(0);
});

// Start the application
app.start().catch((error) => {
  console.error('❌ Failed to start n.crisis server:', error);
  process.exit(1);
});