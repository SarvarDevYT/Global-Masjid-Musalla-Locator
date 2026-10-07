const app = require('./app');
const config = require('./config');
const { dbManager } = require('./db/database');

async function startServer() {
  await dbManager.initialize();

  const server = app.listen(config.port, () => {
    console.log(`
🕌 ==================================================== 🕌
   Global Masjid & Musalla Locator Backend Server
   Port: ${config.port}
   Environment: ${config.nodeEnv}
   Database: ${dbManager.isPostgresConnected ? 'Neon PostGIS (Live)' : 'In-Memory Spatial Store (Standalone)'}
   Health: http://localhost:${config.port}${config.apiPrefix}/health
   Nearby API: http://localhost:${config.port}${config.apiPrefix}/mosques/nearby?lat=41.3381&lng=69.2415&radius=10000
🕌 ==================================================== 🕌
    `);
  });

  const shutdown = async () => {
    console.log('Shutting down server gracefully...');
    server.close(() => {
      console.log('Server closed.');
      process.exit(0);
    });
  };

  process.on('SIGTERM', shutdown);
  process.on('SIGINT', shutdown);
}

startServer().catch(err => {
  console.error('Failed to start server:', err);
  process.exit(1);
});
