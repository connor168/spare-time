import Fastify, { type FastifyReply, type FastifyRequest } from 'fastify';
import cors from '@fastify/cors';
import type pg from 'pg';
import { loadConfig, type Config } from './config.js';
import { createPool } from './db.js';
import { hashPassword, verifyPassword } from './password.js';
import { createRefreshToken, hashRefreshToken, issueAccessToken, verifyAccessToken } from './tokens.js';
import { exchangeWechatCode } from './wechat.js';

type AuthBody = { mode?: 'signup'; email?: string; password?: string };
type WechatBody = { code?: string };
type RefreshBody = { refresh_token?: string };
type SyncPushBody = { tasks?: SyncRow[]; notes?: SyncRow[] };
type SyncRow = Record<string, unknown>;
type SyncPullQuery = { entity?: 'tasks' | 'notes'; cursor?: string };
type DeviceTokenBody = { platform?: string; provider?: string; token?: string };
type DeviceTokenQuery = { token?: string };

export function buildApp(config: Config, pool: pg.Pool) {
  const app = Fastify({ logger: config.nodeEnv !== 'test' });
  app.register(cors, { origin: false });

  app.get('/health', async () => ({ status: 'ok' }));

  app.post<{ Body: AuthBody }>('/api/auth/email', async (request, reply) => {
    const email = request.body?.email?.trim().toLowerCase();
    const password = request.body?.password;
    if (!email || !password || password.length < 8) return reply.code(400).send({ error: 'Invalid email or password' });
    const existing = await pool.query<{ id: string; password_hash: string | null }>(
      'select id, password_hash from users where email = $1', [email]);
    let userId: string;
    if (request.body?.mode === 'signup') {
      if (existing.rowCount) return reply.code(409).send({ error: 'Email is already registered' });
      const created = await pool.query<{ id: string }>(
        'insert into users (email, password_hash) values ($1, $2) returning id', [email, await hashPassword(password)]);
      userId = created.rows[0].id;
    } else {
      const user = existing.rows[0];
      if (!user?.password_hash || !(await verifyPassword(password, user.password_hash))) {
        return reply.code(401).send({ error: 'Invalid email or password' });
      }
      userId = user.id;
    }
    return issueSession(config, pool, userId);
  });

  app.post<{ Body: WechatBody }>('/api/auth/wechat', async (request, reply) => {
    const code = request.body?.code?.trim();
    if (!code || code.length > 256) return reply.code(400).send({ error: 'Missing authorization code' });
    if (!config.wechatAppId || !config.wechatAppSecret) return reply.code(503).send({ error: 'WeChat login is not configured' });
    try {
      const identity = await exchangeWechatCode(config.wechatAppId, config.wechatAppSecret, code);
      const existing = await pool.query<{ user_id: string }>(
        'select user_id from oauth_identities where provider = $1 and subject = $2', ['wechat', identity.subject]);
      let userId = existing.rows[0]?.user_id;
      if (!userId) {
        const created = await pool.query<{ id: string }>('insert into users (display_name, avatar_url) values ($1, $2) returning id', [identity.nickname, identity.avatarUrl]);
        userId = created.rows[0].id;
        await pool.query('insert into oauth_identities (provider, subject, user_id, profile) values ($1, $2, $3, $4)', ['wechat', identity.subject, userId, JSON.stringify({ nickname: identity.nickname, avatar_url: identity.avatarUrl })]);
      }
      return issueSession(config, pool, userId);
    } catch {
      return reply.code(502).send({ error: 'WeChat login failed' });
    }
  });

  app.post<{ Body: RefreshBody }>('/api/auth/refresh', async (request, reply) => {
    const raw = request.body?.refresh_token?.trim();
    if (!raw) return reply.code(400).send({ error: 'Missing refresh token' });
    const client = await pool.connect();
    try {
      await client.query('begin');
      const result = await client.query<{ user_id: string }>(
        'select user_id from refresh_tokens where token_hash = $1 and revoked_at is null and expires_at > now() for update', [hashRefreshToken(raw)]);
      const row = result.rows[0];
      if (!row) {
        await client.query('rollback');
        return reply.code(401).send({ error: 'Invalid refresh token' });
      }
      await client.query('update refresh_tokens set revoked_at = now() where token_hash = $1', [hashRefreshToken(raw)]);
      await client.query('commit');
      return issueSession(config, pool, row.user_id);
    } catch (error) {
      await client.query('rollback');
      throw error;
    } finally {
      client.release();
    }
  });

  app.post('/api/auth/logout', { preHandler: authenticate(config) }, async (request, reply) => {
    await pool.query('update refresh_tokens set revoked_at = now() where user_id = $1 and revoked_at is null', [request.userId]);
    return reply.code(204).send();
  });

  app.get('/api/me', { preHandler: authenticate(config) }, async (request, reply) => {
    const result = await pool.query('select id, email, display_name, avatar_url, created_at from users where id = $1', [request.userId]);
    const user = result.rows[0];
    return user ? user : reply.code(404).send({ error: 'User not found' });
  });

  app.post<{ Body: SyncPushBody }>('/api/sync/push', { preHandler: authenticate(config) }, async (request) => {
    const tasks = await pushRows(pool, 'tasks', request.userId, request.body?.tasks ?? []);
    const notes = await pushRows(pool, 'notes', request.userId, request.body?.notes ?? []);
    return { tasks, notes };
  });

  app.get<{ Querystring: SyncPullQuery }>('/api/sync/pull', { preHandler: authenticate(config) }, async (request, reply) => {
    const entity = request.query?.entity;
    if (entity !== 'tasks' && entity !== 'notes') {
      return reply.code(400).send({ error: 'entity must be tasks or notes' });
    }
    const cursor = request.query.cursor?.trim() || null;
    let cursorTime: string | null = null;
    let cursorId: string | null = null;
    if (cursor) {
      const separator = cursor.indexOf('|');
      cursorTime = separator < 0 ? cursor : cursor.slice(0, separator);
      cursorId = separator < 0 ? null : cursor.slice(separator + 1);
      if (!cursorTime || !cursorId || Number.isNaN(Date.parse(cursorTime))) {
        return reply.code(400).send({ error: 'Invalid sync cursor' });
      }
    }
    const table = entity === 'tasks' ? 'tasks' : 'notes';
    const result = await pool.query(
      `select * from ${table} where user_id = $1 and ($2::timestamptz is null or (updated_at, id) > ($2::timestamptz, $3::uuid)) order by updated_at asc, id asc limit 500`,
      [request.userId, cursorTime, cursorId]);
    const last = result.rows.at(-1)?.updated_at;
    const lastId = result.rows.at(-1)?.id;
    return {
      items: result.rows,
      next_cursor: last && lastId ? `${new Date(last).toISOString()}|${lastId}` : cursor,
    };
  });

  app.post('/api/account/export', { preHandler: authenticate(config) }, async (request) => {
    const [tasks, notes] = await Promise.all([
      pool.query('select * from tasks where user_id = $1 order by updated_at asc, id asc', [request.userId]),
      pool.query('select * from notes where user_id = $1 order by updated_at asc, id asc', [request.userId]),
    ]);
    return { tasks: tasks.rows, notes: notes.rows };
  });

  app.post('/api/account/delete', { preHandler: authenticate(config) }, async (request, reply) => {
    await pool.query('delete from users where id = $1', [request.userId]);
    return reply.code(204).send();
  });

  app.post<{ Body: DeviceTokenBody }>('/api/device-tokens', { preHandler: authenticate(config) }, async (request, reply) => {
    const platform = request.body?.platform?.trim();
    const provider = request.body?.provider?.trim();
    const token = request.body?.token?.trim();
    if (!platform || !provider || !token || token.length > 4096) {
      return reply.code(400).send({ error: 'Invalid device token' });
    }
    await pool.query(
      `insert into device_tokens (user_id, platform, provider, token) values ($1, $2, $3, $4)
       on conflict (token) do update set user_id=excluded.user_id, platform=excluded.platform, provider=excluded.provider, updated_at=now()`,
      [request.userId, platform, provider, token],
    );
    return reply.code(204).send();
  });

  app.delete<{ Querystring: DeviceTokenQuery }>('/api/device-tokens', { preHandler: authenticate(config) }, async (request, reply) => {
    const token = request.query?.token?.trim();
    if (!token) return reply.code(400).send({ error: 'Missing device token' });
    await pool.query('delete from device_tokens where user_id = $1 and token = $2', [request.userId, token]);
    return reply.code(204).send();
  });

  return app;

  function authenticate(current: Config) {
    return async (request: FastifyRequest, reply: FastifyReply) => {
      const header = request.headers.authorization;
      const token = header?.startsWith('Bearer ') ? header.slice(7) : null;
      if (!token) return reply.code(401).send({ error: 'Unauthorized' });
      try {
        request.userId = (await verifyAccessToken(current, token)).userId;
      } catch {
        return reply.code(401).send({ error: 'Unauthorized' });
      }
    };
  }
}

async function pushRows(
  pool: pg.Pool,
  entity: 'tasks' | 'notes',
  userId: string,
  rows: SyncRow[],
): Promise<{ accepted: number; conflicts: number }> {
  if (rows.length > 500) throw new Error('A sync push may contain at most 500 rows');
  if (rows.length === 0) return { accepted: 0, conflicts: 0 };
  const client = await pool.connect();
  let accepted = 0;
  let conflicts = 0;
  try {
    await client.query('begin');
    for (const row of rows) {
      const id = typeof row.id === 'string' ? row.id : '';
      const version = Number(row.version);
      const baseVersion = Number(row.base_version ?? 0);
      if (!id || !Number.isInteger(version) || !Number.isInteger(baseVersion)) {
        throw new Error(`Invalid ${entity} sync row`);
      }
      const current = await client.query<{ user_id: string; version: number }>(
        `select user_id, version from ${entity} where id = $1 for update`, [id]);
      if (current.rowCount &&
          (current.rows[0].user_id !== userId || current.rows[0].version !== baseVersion)) {
        conflicts += 1;
        await client.query(
          'insert into sync_conflicts (user_id, entity_type, entity_id, local_payload, remote_payload) values ($1, $2, $3, $4, $5)',
          [userId, entity, id, JSON.stringify(row), JSON.stringify({ version: current.rows[0].version })],
        );
        continue;
      }
      if (entity === 'tasks') {
        await client.query(
          `insert into tasks (id, user_id, title, description, kind, location, start_at, end_at, timezone_id, repeat_rule, reminder_minutes, reminder_enabled, status, priority, version, created_at, updated_at, deleted_at)
           values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18)
           on conflict (id) do update set title=excluded.title, description=excluded.description, kind=excluded.kind, location=excluded.location, start_at=excluded.start_at, end_at=excluded.end_at, timezone_id=excluded.timezone_id, repeat_rule=excluded.repeat_rule, reminder_minutes=excluded.reminder_minutes, reminder_enabled=excluded.reminder_enabled, status=excluded.status, priority=excluded.priority, version=excluded.version, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at`,
          [id, userId, row.title, row.description ?? '', row.kind ?? 'task', row.location ?? '', row.start_at, row.end_at, row.timezone_id ?? 'UTC', JSON.stringify(row.repeat_rule ?? { type: 'none' }), row.reminder_minutes ?? 5, row.reminder_enabled ?? true, row.status ?? 'planned', row.priority ?? 2, version, row.created_at, row.updated_at, row.deleted_at ?? null],
        );
      } else {
        await client.query(
          `insert into notes (id, user_id, title, body_markdown, tags, is_favorite, version, created_at, updated_at, deleted_at)
           values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
           on conflict (id) do update set title=excluded.title, body_markdown=excluded.body_markdown, tags=excluded.tags, is_favorite=excluded.is_favorite, version=excluded.version, updated_at=excluded.updated_at, deleted_at=excluded.deleted_at`,
          [id, userId, row.title, row.body_markdown ?? '', JSON.stringify(row.tags ?? []), row.is_favorite ?? false, version, row.created_at, row.updated_at, row.deleted_at ?? null],
        );
      }
      accepted += 1;
    }
    await client.query('commit');
    return { accepted, conflicts };
  } catch (error) {
    await client.query('rollback');
    throw error;
  } finally {
    client.release();
  }
}

async function issueSession(config: Config, pool: pg.Pool, userId: string) {
  const refreshToken = createRefreshToken();
  await pool.query(
    'insert into refresh_tokens (user_id, token_hash, expires_at) values ($1, $2, now() + interval \'30 days\')',
    [userId, hashRefreshToken(refreshToken)]);
  return {
    access_token: await issueAccessToken(config, userId),
    refresh_token: refreshToken,
    expires_in: config.accessTokenTtlSeconds,
    user: { id: userId },
  };
}

declare module 'fastify' {
  interface FastifyRequest { userId: string }
}

if (process.env.NODE_ENV !== 'test') {
  const config = loadConfig();
  const pool = createPool(config);
  const app = buildApp(config, pool);
  app.listen({ port: config.port, host: '0.0.0.0' }).catch((error) => {
    app.log.error(error);
    process.exit(1);
  });
}
