create extension if not exists pgcrypto;

create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(trim(title)) between 1 and 200),
  description text not null default '',
  start_at timestamptz not null,
  end_at timestamptz not null,
  timezone_id text not null,
  repeat_rule jsonb not null default '{"type":"none"}'::jsonb,
  reminder_minutes integer not null default 0 check (reminder_minutes between 0 and 1440),
  status text not null default 'planned' check (status in ('planned', 'completed', 'cancelled')),
  priority smallint not null default 2 check (priority between 1 and 3),
  version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  check (end_at > start_at)
);

create table if not exists public.notes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(trim(title)) between 1 and 200),
  body_markdown text not null default '',
  tags text[] not null default '{}',
  is_favorite boolean not null default false,
  version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.news_items (
  id uuid primary key default gen_random_uuid(),
  repository_full_name text not null,
  title text not null,
  summary text not null default '',
  source_url text not null,
  tags text[] not null default '{}',
  stars integer not null default 0,
  forks integer not null default 0,
  score numeric not null default 0,
  published_at timestamptz,
  fetched_at timestamptz not null default now(),
  summary_version text not null default 'raw-description',
  unique (repository_full_name, published_at)
);

create table if not exists public.user_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  timezone_id text not null default 'Asia/Tokyo',
  topics text[] not null default '{artificial-intelligence,llm,generative-ai,agent}',
  digest_time time not null default '08:00',
  quiet_start time,
  quiet_end time,
  push_enabled boolean not null default true,
  updated_at timestamptz not null default now()
);

create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null check (platform in ('android', 'ios')),
  provider text not null check (provider in ('fcm', 'apns', 'hms')),
  token text not null unique,
  last_seen_at timestamptz not null default now(),
  invalid_at timestamptz
);

create index if not exists tasks_user_start_idx on public.tasks(user_id, start_at) where deleted_at is null;
create index if not exists notes_user_updated_idx on public.notes(user_id, updated_at desc) where deleted_at is null;
create index if not exists news_fetched_idx on public.news_items(fetched_at desc);

alter table public.tasks enable row level security;
alter table public.notes enable row level security;
alter table public.user_preferences enable row level security;
alter table public.device_tokens enable row level security;

drop policy if exists "users manage their own tasks" on public.tasks;
create policy "users manage their own tasks" on public.tasks for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "users manage their own notes" on public.notes;
create policy "users manage their own notes" on public.notes for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "users manage their own preferences" on public.user_preferences;
create policy "users manage their own preferences" on public.user_preferences for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "users manage their own device tokens" on public.device_tokens;
create policy "users manage their own device tokens" on public.device_tokens for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "authenticated users read news" on public.news_items;
create policy "authenticated users read news" on public.news_items for select to authenticated using (true);
