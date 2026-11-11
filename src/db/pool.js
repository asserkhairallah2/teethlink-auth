// TeethLink_Auth_System/src/db/pool.js
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { PGlite } from '@electric-sql/pglite';
import { AppError } from '../utils/errors.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '../../');
const pgDataDir = path.join(rootDir, '.pgdata');

// Clean up stale lock files if any
try {
  const pidFile = path.join(pgDataDir, 'postmaster.pid');
  if (fs.existsSync(pidFile)) fs.unlinkSync(pidFile);
  const files = fs.existsSync(pgDataDir) ? fs.readdirSync(pgDataDir) : [];
  for (const f of files) {
    if (f.endsWith('.lock') || f.includes('.lock.')) {
      fs.unlinkSync(path.join(pgDataDir, f));
    }
  }
} catch {
  // ignore
}

console.log(`[DB Pool] Initializing PGlite embedded database at ${pgDataDir}...`);
const pglite = await PGlite.create(pgDataDir);

// Auto-run schema.sql and seed.sql if tables do not exist
try {
  const checkRes = await pglite.query(
    "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'users') AS ex"
  );
  const exists = checkRes.rows[0]?.ex;
  if (!exists) {
    console.log('[DB Pool] Applying schema.sql...');
    const schemaSql = fs.readFileSync(path.join(rootDir, 'sql', 'schema.sql'), 'utf8');
    await pglite.exec(schemaSql);

    console.log('[DB Pool] Applying seed.sql...');
    const seedSql = fs.readFileSync(path.join(rootDir, 'sql', 'seed.sql'), 'utf8');
    await pglite.exec(seedSql);
    console.log('[DB Pool] Database schema & seed applied successfully.');
  } else {
    console.log('[DB Pool] Database tables already present.');
  }
} catch (err) {
  console.error('[DB Pool] Error during auto-migration:', err);
}

/**
 * Maps PostgreSQL SQLSTATE error codes to structured AppError instances.
 */
export function mapPgError(err, lockContext = null) {
  if (err instanceof AppError) return err;
  const sqlState = err?.code || '';

  // 23505: unique_violation
  if (sqlState === '23505') {
    return new AppError(
      409,
      'DUPLICATE_RESOURCE',
      'A record with the same unique identifier (phone, email, or code) already exists.',
      { sqlState, detail: err.detail || null }
    );
  }

  // 23503: foreign_key_violation
  if (sqlState === '23503') {
    return new AppError(
      422,
      'INVALID_REFERENCE',
      'One or more referenced identifiers do not exist.',
      { sqlState, detail: err.detail || null }
    );
  }

  // 23514: check_violation
  if (sqlState === '23514') {
    return new AppError(
      422,
      'CONSTRAINT_VIOLATION',
      `Database check constraint violated (${err.constraint || 'unknown'}).`,
      { sqlState, detail: err.detail || null }
    );
  }

  return err;
}

/**
 * Standard pg-compatible query wrapper over PGlite
 */
export const pool = {
  async query(text, params = []) {
    try {
      return await pglite.query(text, params);
    } catch (err) {
      throw mapPgError(err);
    }
  },
  async exec(sql) {
    return pglite.exec(sql);
  },
  async connect() {
    return {
      query: (text, params) => pglite.query(text, params),
      release: () => {},
    };
  },
};

export async function query(text, params = []) {
  return pool.query(text, params);
}

/**
 * Transaction helper with post-commit callbacks
 */
export async function withTransaction(callback) {
  const postCommitCallbacks = [];
  const afterCommit = (cb) => {
    if (typeof cb === 'function') postCommitCallbacks.push(cb);
  };

  const client = {
    query: (text, params) => pglite.query(text, params),
  };

  await pglite.query('BEGIN');
  try {
    const result = await callback(client, afterCommit);
    await pglite.query('COMMIT');

    if (postCommitCallbacks.length > 0) {
      for (const cb of postCommitCallbacks) {
        try {
          await cb();
        } catch (cbErr) {
          console.error('[afterCommit] Callback failed:', cbErr);
        }
      }
    }

    return result;
  } catch (err) {
    try {
      await pglite.query('ROLLBACK');
    } catch {}
    throw mapPgError(err);
  }
}

export default pool;
