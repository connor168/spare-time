# Focus Flow API contract

The production backend is an Aliyun-hosted service. Supabase is not part of
the production authentication path. During migration, `SupabaseRestClient`
remains only as a compatibility adapter for existing accounts and tests.

## Authentication

All session responses use this shape:

```json
{
  "access_token": "...",
  "refresh_token": "...",
  "expires_in": 900,
  "user": { "id": "uuid" }
}
```

```text
POST /api/auth/email
POST /api/auth/wechat       { "code": "..." }
POST /api/auth/refresh      { "refresh_token": "..." }
POST /api/auth/logout       Authorization: Bearer <access token>
GET  /api/me                Authorization: Bearer <access token>
```

The WeChat AppSecret is read only by the server from its environment. It must
never be included in Flutter build arguments, Android resources, Git, or logs.
Refresh tokens are stored as hashes, rotated on refresh, and revoked on logout.

## Sync

Sync endpoints are implemented in the API client and server scaffold. Before
production deployment they still require a PostgreSQL integration test. The
contract preserves UUIDs, soft deletes, per-record revisions, and an explicit
conflict result:

```text
POST /api/sync/push
GET  /api/sync/pull
```

Push accepts `{ "tasks": [...], "notes": [...] }`. Each record carries
`version` and `base_version`; the response returns per-entity `accepted` and
`conflicts` counts. Pull accepts `entity=tasks|notes` and an optional opaque
cursor containing the last `(updated_at, id)` pair, returning
`{ "items": [...], "next_cursor": "..." }`.

The server must scope every record by the authenticated user and reject a push
whose `base_version` does not match the current server version.

## Account data

```text
POST /api/account/delete
POST /api/account/export
POST /api/device-tokens
DELETE /api/device-tokens?token=<encoded token>
```

These operations require authentication and must be idempotent.
