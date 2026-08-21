import { readFile } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { buildApp } from '../src/server.js';
import { createPool } from '../src/db.js';
import type { Config } from '../src/config.js';
import type pg from 'pg';

const databaseUrl = process.env.FOCUS_FLOW_TEST_DATABASE_URL;
const suite = databaseUrl ? describe : describe.skip;

suite('Focus Flow API PostgreSQL integration', () => {
  let pool: pg.Pool | undefined;
  let app: ReturnType<typeof buildApp> | undefined;
  const createdUserIds: string[] = [];
  const runId = randomUUID();
  const email = `focus-flow-test-${runId}@example.invalid`;
  const password = 'correct-horse-battery-staple';

  beforeAll(async () => {
    if (!databaseUrl) throw new Error('FOCUS_FLOW_TEST_DATABASE_URL is required');
    pool = createPool(databaseUrl);
    await applyMigrations(pool);
    app = buildApp(testConfig(databaseUrl), pool);
  });

  afterAll(async () => {
    if (pool && createdUserIds.length > 0) {
      await pool.query('delete from users where id = any($1::uuid[])', [createdUserIds]);
    }
    await app?.close();
    await pool?.end();
  });

  it('persists authentication, rotates refresh tokens, syncs with CAS, and deletes an account', async () => {
    const currentApp = app;
    if (!currentApp) throw new Error('The integration app was not initialized');

    const signup = await currentApp.inject({
      method: 'POST',
      url: '/api/auth/email',
      payload: { mode: 'signup', email, password },
    });
    expect(signup.statusCode).toBe(200);
    const firstSession = signup.json() as Session;
    createdUserIds.push(firstSession.user.id);
    expect(firstSession.access_token).toBeTypeOf('string');
    expect(firstSession.refresh_token).toBeTypeOf('string');

    const me = await currentApp.inject({
      method: 'GET',
      url: '/api/me',
      headers: authorization(firstSession.access_token),
    });
    expect(me.statusCode).toBe(200);
    expect(me.json()).toMatchObject({ id: firstSession.user.id, email });

    const refresh = await currentApp.inject({
      method: 'POST',
      url: '/api/auth/refresh',
      payload: { refresh_token: firstSession.refresh_token },
    });
    expect(refresh.statusCode).toBe(200);
    const secondSession = refresh.json() as Session;
    expect(secondSession.refresh_token).not.toBe(firstSession.refresh_token);

    const reusedRefresh = await currentApp.inject({
      method: 'POST',
      url: '/api/auth/refresh',
      payload: { refresh_token: firstSession.refresh_token },
    });
    expect(reusedRefresh.statusCode).toBe(401);

    const now = new Date().toISOString();
    const taskId = randomUUID();
    const noteId = randomUUID();
    const sync = await currentApp.inject({
      method: 'POST',
      url: '/api/sync/push',
      headers: authorization(secondSession.access_token),
      payload: {
        tasks: [task(taskId, now)],
        notes: [note(noteId, now)],
      },
    });
    expect(sync.statusCode).toBe(200);
    expect(sync.json()).toEqual({
      tasks: { accepted: 1, conflicts: 0 },
      notes: { accepted: 1, conflicts: 0 },
    });

    const conflict = await currentApp.inject({
      method: 'POST',
      url: '/api/sync/push',
      headers: authorization(secondSession.access_token),
      payload: { tasks: [{ ...task(taskId, now), title: 'stale edit', version: 2, base_version: 0 }] },
    });
    expect(conflict.statusCode).toBe(200);
    expect(conflict.json()).toEqual({
      tasks: { accepted: 0, conflicts: 1 },
      notes: { accepted: 0, conflicts: 0 },
    });

    const pull = await currentApp.inject({
      method: 'GET',
      url: '/api/sync/pull?entity=tasks',
      headers: authorization(secondSession.access_token),
    });
    expect(pull.statusCode).toBe(200);
    expect(pull.json().items).toEqual([expect.objectContaining({ id: taskId, title: 'Integration task' })]);

    const registerToken = await currentApp.inject({
      method: 'POST',
      url: '/api/device-tokens',
      headers: authorization(secondSession.access_token),
      payload: { platform: 'android', provider: 'fcm', token: `token-${runId}` },
    });
    expect(registerToken.statusCode).toBe(204);

    const exported = await currentApp.inject({
      method: 'POST',
      url: '/api/account/export',
      headers: authorization(secondSession.access_token),
    });
    expect(exported.statusCode).toBe(200);
    expect(exported.json()).toMatchObject({
      tasks: [expect.objectContaining({ id: taskId })],
      notes: [expect.objectContaining({ id: noteId })],
    });

    const revokeToken = await currentApp.inject({
      method: 'DELETE',
      url: `/api/device-tokens?token=${encodeURIComponent(`token-${runId}`)}`,
      headers: authorization(secondSession.access_token),
    });
    expect(revokeToken.statusCode).toBe(204);

    const deleted = await currentApp.inject({
      method: 'POST',
      url: '/api/account/delete',
      headers: authorization(secondSession.access_token),
    });
    expect(deleted.statusCode).toBe(204);
    createdUserIds.length = 0;

    const afterDelete = await currentApp.inject({
      method: 'GET',
      url: '/api/me',
      headers: authorization(secondSession.access_token),
    });
    expect(afterDelete.statusCode).toBe(404);
  });
});

async function applyMigrations(pool: pg.Pool) {
  for (const migration of ['001_initial.sql', '002_product_and_sync.sql']) {
    await pool.query(await readFile(new URL(`../migrations/${migration}`, import.meta.url), 'utf8'));
  }
}

function testConfig(databaseUrl: string): Config {
  return {
    nodeEnv: 'test',
    port: 0,
    databaseUrl,
    jwtSecret: new TextEncoder().encode('a'.repeat(32)),
    jwtIssuer: 'focus-flow-integration-test',
    accessTokenTtlSeconds: 900,
    wechatAppId: null,
    wechatAppSecret: null,
  };
}

function authorization(token: string) {
  return { authorization: `Bearer ${token}` };
}

function task(id: string, time: string) {
  return {
    id,
    title: 'Integration task',
    description: '',
    kind: 'task',
    location: '',
    start_at: time,
    end_at: time,
    timezone_id: 'UTC',
    repeat_rule: { type: 'none' },
    reminder_minutes: 5,
    reminder_enabled: true,
    status: 'planned',
    priority: 2,
    version: 1,
    base_version: 0,
    created_at: time,
    updated_at: time,
  };
}

function note(id: string, time: string) {
  return {
    id,
    title: 'Integration note',
    body_markdown: 'content',
    tags: ['integration'],
    is_favorite: false,
    version: 1,
    base_version: 0,
    created_at: time,
    updated_at: time,
  };
}

type Session = {
  access_token: string;
  refresh_token: string;
  user: { id: string };
};
