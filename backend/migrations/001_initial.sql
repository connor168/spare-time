create extension if not exists pgcrypto;

create table if not exists users (
  id uuid primary key default gen_random_uuid(),
  email text unique,
  password_hash text,
  display_name text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists oauth_identities (
  provider text not null,
  subject text not null,
  user_id uuid not null references users(id) on delete cascade,
  profile jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (provider, subject),
  constraint oauth_provider_check check (provider in ('wechat'))
);

create unique index if not exists oauth_identity_user_provider_idx
  on oauth_identities(provider, user_id);

create table if not exists refresh_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  token_hash text not null unique,
  expires_at timestamptz not null,
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists refresh_tokens_user_idx on refresh_tokens(user_id);

create table if not exists tasks (
  id uuid primary key,
  user_id uuid not null references users(id) on delete cascade,
  title text not null,
  description text not null default '',
  kind text not null default 'task',
  location text not null default '',
  start_at timestamptz not null,
  end_at timestamptz not null,
  timezone_id text not null default 'UTC',
  repeat_rule jsonb not null default '{"type":"none"}',
  reminder_minutes integer not null default 5,
  reminder_enabled boolean not null default true,
  status text not null default 'planned',
  priority integer not null default 2,
  version integer not null default 1,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz
);

create index if not exists tasks_user_updated_idx on tasks(user_id, updated_at, id);

create table if not exists notes (
  id uuid primary key,
  user_id uuid not null references users(id) on delete cascade,
  title text not null,
  body_markdown text not null default '',
  tags jsonb not null default '[]',
  is_favorite boolean not null default false,
  version integer not null default 1,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz
);

create index if not exists notes_user_updated_idx on notes(user_id, updated_at, id);
