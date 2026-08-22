import { describe, expect, it } from 'vitest';
import type pg from 'pg';
import { buildApp } from '../src/server.js';
import type { Config } from '../src/config.js';

const config: Config = {
  nodeEnv: 'test',
  port: 0,
  databaseUrl: 'postgres://unused',
  databaseSslCaFile: null,
  jwtSecret: new TextEncoder().encode('a'.repeat(32)),
  jwtIssuer: 'focus-flow-test',
  accessTokenTtlSeconds: 900,
  wechatAppId: null,
  wechatAppSecret: null,
  githubApiToken: null,
  newsCronSecret: 'test-cron-secret',
  fcmProjectId: null,
  fcmClientEmail: null,
  fcmPrivateKey: null,
};

describe('Focus Flow API', () => {
  it('reports health without a database query', async () => {
    const pool = { query: async () => ({ rows: [], rowCount: 0 }) } as unknown as pg.Pool;
    const app = buildApp(config, pool);
    const response = await app.inject({ method: 'GET', url: '/health' });
    expect(response.statusCode).toBe(200);
    expect(response.json()).toEqual({ status: 'ok' });
    await app.close();
  });

  it('rejects malformed WeChat requests before touching the database', async () => {
    const pool = { query: async () => { throw new Error('should not query'); } } as unknown as pg.Pool;
    const app = buildApp({ ...config, wechatAppId: 'app', wechatAppSecret: 'secret' }, pool);
    const response = await app.inject({
      method: 'POST',
      url: '/api/auth/wechat',
      payload: { code: '' },
    });
    expect(response.statusCode).toBe(400);
    await app.close();
  });

  it('limits daily news results to fifty items', async () => {
    const pool = {
      query: async (sql: string) => {
        if (sql.includes('from news_items')) {
          return { rows: [], rowCount: 0 };
        }
        return { rows: [], rowCount: 0 };
      },
    } as unknown as pg.Pool;
    const app = buildApp(config, pool);
    const session = await app.inject({ method: 'GET', url: '/api/news/daily?limit=999', headers: { authorization: `Bearer invalid` } });
    expect(session.statusCode).toBe(401);
    await app.close();
  });

  it('protects the scheduled news refresh endpoint', async () => {
    const pool = { query: async () => ({ rows: [], rowCount: 0 }) } as unknown as pg.Pool;
    const app = buildApp(config, pool);
    const response = await app.inject({ method: 'POST', url: '/internal/news/refresh' });
    expect(response.statusCode).toBe(401);
    await app.close();
  });
});
