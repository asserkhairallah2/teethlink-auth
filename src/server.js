// TeethLink_Auth_System/src/server.js
import 'dotenv/config';
import http from 'node:http';
import { app } from './app.js';
import { pool } from './db/pool.js';

const PORT = Number(process.env.PORT || 5000);
const HOST = process.env.HOST || '0.0.0.0';

const server = http.createServer(app);

// Verify database connection on startup
try {
  const result = await pool.query('SELECT NOW() AS now');
  console.log(`[Server] Connected to PGlite database at ${result.rows[0].now}`);
} catch (err) {
  console.error('[Server] Fatal: Database connection failed:', err);
  process.exit(1);
}

server.listen(PORT, HOST, () => {
  console.log(`\n============================================================`);
  console.log(`  TeethLink Authentication & Schemas Subsystem (Active)`);
  console.log(`============================================================`);
  console.log(`  Web GUI:          http://localhost:${PORT}`);
  console.log(`  Schemas Viewer:   http://localhost:${PORT}/#schemas`);
  console.log(`  Health Check:     http://localhost:${PORT}/api/v1/health`);
  console.log(`  API Base:         http://localhost:${PORT}/api/v1`);
  console.log(`============================================================\n`);
});

// Graceful shutdown
function shutdown(signal) {
  console.log(`\n[Server] Received ${signal}. Shutting down cleanly...`);
  server.close(() => {
    console.log('[Server] HTTP server closed.');
    process.exit(0);
  });
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
