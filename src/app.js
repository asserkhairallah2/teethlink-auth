// TeethLink_Auth_System/src/app.js
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import crypto from 'node:crypto';
import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import { pool } from './db/pool.js';
import { errorHandler } from './middlewares/errorHandler.js';
import authRoutes from './modules/auth/auth.routes.js';
import adminAccountsRoutes from './modules/admin/admin-accounts.routes.js';
import { getQuestionnaireHandler } from './modules/auth/auth.controller.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '../');

export const app = express();

// Security headers
app.use(
  helmet({
    contentSecurityPolicy: false,
    crossOriginEmbedderPolicy: false,
  })
);

// CORS
app.use(
  cors({
    origin: '*',
    credentials: true,
  })
);

// Body parsing
app.use(express.json({ limit: '5mb' }));
app.use(express.urlencoded({ extended: true, limit: '5mb' }));

// Request ID middleware
app.use((req, res, next) => {
  req.requestId = req.headers['x-request-id'] || `req_${crypto.randomUUID()}`;
  res.setHeader('X-Request-Id', req.requestId);
  next();
});

// Serve frontend static assets (GUI, Schemas, Diagrams)
app.use(express.static(path.join(rootDir, 'public')));

// -----------------------------------------------------------------------------
// Health Check Endpoint
// -----------------------------------------------------------------------------
app.get('/api/v1/health', async (_req, res) => {
  try {
    const dbRes = await pool.query('SELECT NOW() AS now');
    const userCount = await pool.query('SELECT COUNT(*)::INT AS count FROM users');
    return res.status(200).json({
      success: true,
      data: {
        status: 'healthy',
        service: 'teethlink-auth-system',
        version: '1.0.0',
        timestamp: new Date().toISOString(),
        database: {
          connected: true,
          engine: 'PostgreSQL 16 (Embedded PGlite)',
          serverTime: dbRes.rows[0]?.now,
          totalUsers: userCount.rows[0]?.count || 0,
        },
      },
    });
  } catch (err) {
    return res.status(503).json({
      success: false,
      error: {
        code: 'HEALTH_CHECK_FAILED',
        message: err.message,
      },
    });
  }
});

// -----------------------------------------------------------------------------
// Demo Overview Stats Endpoint
// -----------------------------------------------------------------------------
app.get('/api/v1/demo/overview', async (_req, res) => {
  try {
    const [uRes, pRes] = await Promise.all([
      pool.query('SELECT COUNT(*)::INT AS total_users FROM users'),
      pool.query("SELECT COUNT(*)::INT AS pending_approvals FROM users WHERE account_status = 'PENDING_APPROVAL'"),
    ]);

    return res.status(200).json({
      success: true,
      data: {
        stats: {
          total_users: uRes.rows[0]?.total_users || 0,
          pending_approvals: pRes.rows[0]?.pending_approvals || 0,
        },
      },
    });
  } catch (err) {
    return res.status(500).json({ success: false, error: { message: err.message } });
  }
});

// -----------------------------------------------------------------------------
// API Routes
// -----------------------------------------------------------------------------
app.use('/api/v1/auth', authRoutes);
app.get('/api/v1/medical-catalog/questionnaire', getQuestionnaireHandler);
app.use('/api/v1/admin/accounts', adminAccountsRoutes);

// Fallback for HTML5 client routing (serves index.html for unknown GET requests)
app.get('*', (req, res, next) => {
  if (req.accepts('html')) {
    return res.sendFile(path.join(rootDir, 'public', 'index.html'));
  }
  next();
});

// 404 handler for unmatched API routes
app.use('/api/*', (req, res) => {
  res.status(404).json({
    success: false,
    error: {
      code: 'ROUTE_NOT_FOUND',
      message: `Cannot ${req.method} ${req.originalUrl}`,
    },
  });
});

// Error handling middleware
app.use(errorHandler);

export default app;
