# Focus Flow Aliyun deployment

This guide deploys the production API as a Docker service on Alibaba Cloud ECS,
with PostgreSQL on Alibaba Cloud RDS and Caddy terminating HTTPS. Supabase is
not part of this path.

## 1. Create cloud resources

In the Alibaba Cloud console, create these resources in the same region:

1. An ECS instance running a current Linux image, with a static public IP.
2. A PostgreSQL RDS instance in the same VPC. Keep the database private: allow
   inbound PostgreSQL only from the ECS security group, never from the internet.
3. A database named `focusflow` and a restricted database account for the API.
4. An ECS security-group rule that permits SSH only from the administrator's
   IP address, plus TCP 80 and 443 for the public API.
5. A DNS `A` record such as `api.example.com` pointing to the ECS public IP.

Download the RDS CA certificate from the RDS console. It is required because the
API verifies PostgreSQL TLS certificates in production.

## 2. Prepare the ECS host

Install Docker Engine and Docker Compose on the ECS host using the operating
system's supported package instructions. Then clone the repository:

```bash
git clone https://github.com/connor168/spare-time.git
cd spare-time/backend
mkdir -p secrets
chmod 700 secrets
```

Copy the downloaded RDS CA certificate to `secrets/rds-ca.pem` and restrict it:

```bash
chmod 600 secrets/rds-ca.pem
```

## 3. Configure server-only secrets

Create `backend/.env` on the ECS host. Do not commit or copy this file into the
Flutter project. Replace every placeholder with the actual production value:

```dotenv
NODE_ENV=production
PORT=8080
DATABASE_URL=postgres://focusflow:URL_ENCODED_DATABASE_PASSWORD@RDS_PRIVATE_ENDPOINT:5432/focusflow
DATABASE_SSL_CA_FILE=/run/secrets/rds-ca.pem
JWT_SECRET=GENERATE_A_NEW_RANDOM_64_HEX_CHARACTER_VALUE
JWT_ISSUER=focus-flow-api
ACCESS_TOKEN_TTL_SECONDS=900
WECHAT_APP_ID=wxYOUR_APP_ID
WECHAT_APP_SECRET=YOUR_SERVER_ONLY_APP_SECRET
API_DOMAIN=api.example.com
```

Generate `JWT_SECRET` on the ECS host with:

```bash
openssl rand -hex 32
```

If the RDS password includes characters such as `@`, `:`, `/`, or `#`, percent
encode it before placing it in `DATABASE_URL`.

## 4. Migrate and start

Build the image, apply migrations once, then start the API and HTTPS proxy:

```bash
docker compose -f docker-compose.production.yml build
docker compose -f docker-compose.production.yml run --rm api npm run migrate
docker compose -f docker-compose.production.yml up -d
docker compose -f docker-compose.production.yml ps
```

The migration command stores applied filenames in `schema_migrations`, takes a
PostgreSQL advisory lock, and can be run again safely during later releases.

Check the public health endpoint:

```bash
curl --fail https://api.example.com/health
```

The expected response is:

```json
{"status":"ok"}
```

If Caddy cannot obtain a certificate, verify that the DNS record has propagated
and that ports 80 and 443 are reachable from the internet. Inspect logs with:

```bash
docker compose -f docker-compose.production.yml logs --tail=100 api caddy
```

## 5. Switch the Flutter client

Build a test APK with the production API URL only after `/health` succeeds:

```bash
flutter build apk --debug --dart-define=FOCUS_FLOW_API_URL=https://api.example.com
```

Run the email login, token refresh, logout, account export/delete, and two-device
sync checks before enabling real user data. Add `WECHAT_APP_SECRET` only after
the WeChat app has passed review and Android device authorization is ready.

## 6. Updates and backups

For every release, pull the committed revision, rebuild, run migrations, and
restart the services:

```bash
git pull --ff-only
docker compose -f docker-compose.production.yml build
docker compose -f docker-compose.production.yml run --rm api npm run migrate
docker compose -f docker-compose.production.yml up -d
```

Enable RDS automated backups and test restoring into a separate non-production
instance before relying on the service for real schedules.
