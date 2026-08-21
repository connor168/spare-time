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

## Production container

The production image compiles TypeScript during its build and starts with Node;
it does not depend on the development-only `tsx` package. It includes the SQL
migrations, which must be run once per release before the API is started:

```text
docker compose -f docker-compose.production.yml build
docker compose -f docker-compose.production.yml run --rm api npm run migrate
docker compose -f docker-compose.production.yml up -d api
```

Copy `.env.example` to `.env` only on the server, set the production database
URL and new random secrets, and keep `.env` outside Git. The production compose
file binds the API to `127.0.0.1:8080`; put an HTTPS reverse proxy in front of it.
`DATABASE_SSL_CA_FILE` must point to the RDS CA certificate mounted at
`/run/secrets/rds-ca.pem`; the sample production compose file does this from
`backend/secrets/rds-ca.pem` on the server. Caddy is included in that compose
file and obtains HTTPS certificates after the DNS record and ports 80/443 work.

## PostgreSQL integration test

The integration suite only runs when a dedicated PostgreSQL database is supplied.
It applies the migrations and exercises email authentication, refresh-token
rotation, sync CAS conflicts, device tokens, export, and account deletion.

```text
FOCUS_FLOW_TEST_DATABASE_URL=postgres://focusflow:change-me@localhost:5432/focusflow_test npm run test:integration
```

Use an isolated test database. Do not point this variable at production: the
suite creates test data and deletes the test account after each run.
