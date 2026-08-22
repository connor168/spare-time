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
tokens, account export/delete, and the daily GitHub digest. `npm run news:refresh`
fetches up to 50 repositories, stores the current Asia/Shanghai digest, and
sends optional FCM notifications to registered devices. Set `GITHUB_API_TOKEN`
for higher GitHub API limits. FCM delivery is enabled only when all three
`FCM_*` variables are configured. The server also exposes
`POST /internal/news/refresh`, protected by `x-cron-secret`, for an ECS cron
job; schedule it daily at 07:00 Asia/Shanghai.

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

After the API is running, configure the host scheduler with:

```text
CRON_TZ=Asia/Shanghai
0 7 * * * cd /opt/focus-flow/spare-time/backend && docker compose -f docker-compose.production.yml run --rm api node dist/refresh-news.js >> /var/log/focus-flow-news.log 2>&1
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
