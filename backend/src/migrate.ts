import { readdir, readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { loadConfig } from './config.js';
import { createPool } from './db.js';

const migrationDirectory = join(process.cwd(), 'migrations');
const config = loadConfig();
const pool = createPool(config);
const client = await pool.connect();

try {
  const migrations = (await readdir(migrationDirectory))
    .filter((name) => /^\d+_.+\.sql$/.test(name))
    .sort();
  await client.query('select pg_advisory_lock(841260315)');
  await client.query(
    `create table if not exists schema_migrations (
      name text primary key,
      applied_at timestamptz not null default now()
    )`,
  );

  for (const name of migrations) {
    const applied = await client.query('select 1 from schema_migrations where name = $1', [name]);
    if (applied.rowCount) continue;

    const sql = await readFile(join(migrationDirectory, name), 'utf8');
    try {
      await client.query('begin');
      await client.query(sql);
      await client.query('insert into schema_migrations (name) values ($1)', [name]);
      await client.query('commit');
      console.log(`Applied ${name}`);
    } catch (error) {
      await client.query('rollback');
      throw error;
    }
  }
} finally {
  await client.query('select pg_advisory_unlock(841260315)').catch(() => undefined);
  client.release();
  await pool.end();
}
