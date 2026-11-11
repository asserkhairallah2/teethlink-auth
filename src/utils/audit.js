// TeethLink_Auth_System/src/utils/audit.js
import net from 'node:net';

const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function normalizeUuidOrNull(rawRequestId) {
  if (!rawRequestId || typeof rawRequestId !== 'string') return null;
  const stripped = rawRequestId.trim().replace(/^req_/i, '');
  return UUID_REGEX.test(stripped) ? stripped.toLowerCase() : null;
}

export function normalizeInetOrNull(rawIp) {
  if (!rawIp || typeof rawIp !== 'string') return null;
  const candidate = rawIp.split(',')[0].trim();
  if (!candidate) return null;
  if (net.isIP(candidate) !== 0) return candidate;
  return null;
}

export async function writeAuditLog(
  dbClient,
  {
    actorUserId = null,
    actorRole = null,
    action,
    entityType,
    entityId = null,
    beforeData = null,
    afterData = null,
    req = undefined,
  }
) {
  try {
    const ipAddress = normalizeInetOrNull(req?.ip || req?.socket?.remoteAddress);
    const userAgent = req?.headers?.['user-agent']?.slice(0, 255) || null;

    await dbClient.query(
      `INSERT INTO audit_logs (
         actor_user_id,
         actor_role,
         action,
         entity_type,
         entity_id,
         before_data,
         after_data,
         ip_address,
         user_agent
       )
       VALUES ($1, $2, $3, $4, $5, $6::jsonb, $7::jsonb, $8, $9)`,
      [
        actorUserId,
        actorRole,
        action,
        entityType,
        entityId,
        beforeData ? JSON.stringify(beforeData) : null,
        afterData ? JSON.stringify(afterData) : null,
        ipAddress,
        userAgent,
      ]
    );
  } catch (err) {
    console.error('[AuditLog] Failed to write audit log:', err.message);
  }
}

export async function createNotification() {
  // Real-time notifications stub for auth subsystem
  return null;
}
