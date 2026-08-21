# Focus Flow API

This is the production-backend starting point for the Aliyun deployment. It
uses Node.js, TypeScript, Fastify, and PostgreSQL.

## Local setup

```text
copy .env.example .env
npm install
psql "$DATABASE_URL" -f migrations/001_initial.sql
npm run typecheck
npm test
npm run dev
```

The service exposes `GET /health`. `JWT_SECRET` and the WeChat AppSecret are
server-only secrets. Do not put `.env` in Git or pass `WECHAT_APP_SECRET` to a
Flutter build.

The initial implementation covers email auth, WeChat code exchange, JWT access
tokens, rotating refresh tokens, logout, `/api/me`, CAS sync push/pull, device
tokens, and account export/delete. PostgreSQL integration tests and production
deployment are still required before enabling the Flutter client against a real
database.

For a local PostgreSQL instance, `docker compose up -d postgres` is sufficient;
apply migrations in order before starting the API. The `docker-compose.yml`
service is a development scaffold, not a production secret-management setup.

## PostgreSQL integration test

The integration suite only runs when a dedicated PostgreSQL database is supplied.
It applies the migrations and exercises email authentication, refresh-token
rotation, sync CAS conflicts, device tokens, export, and account deletion.

```text
FOCUS_FLOW_TEST_DATABASE_URL=postgres://focusflow:change-me@localhost:5432/focusflow_test npm run test:integration
```

Use an isolated test database. Do not point this variable at production: the
suite creates test data and deletes the test account after each run.
