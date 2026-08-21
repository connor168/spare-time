import pg from 'pg';
import { readFileSync } from 'node:fs';
import type { Config } from './config.js';

const { Pool } = pg;

export function createPool(config: Pick<Config, 'databaseUrl' | 'nodeEnv' | 'databaseSslCaFile'>): pg.Pool {
  const ssl = config.nodeEnv === 'production'
    ? {
        rejectUnauthorized: true,
        ca: readFileSync(config.databaseSslCaFile!, 'utf8'),
      }
    : undefined;
  return new Pool({
    connectionString: config.databaseUrl,
    max: 10,
    idleTimeoutMillis: 30_000,
    connectionTimeoutMillis: 5_000,
    ssl,
  });
}
