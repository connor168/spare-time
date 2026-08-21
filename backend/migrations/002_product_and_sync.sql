create table if not exists courses (
  id uuid primary key,
  user_id uuid not null references users(id) on delete cascade,
  name text not null,
  weekday smallint not null check (weekday between 1 and 7),
  starts_at time not null,
  ends_at time not null,
  location text not null default '',
  first_week smallint,
  last_week smallint,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index if not exists courses_user_updated_idx on courses(user_id, updated_at, id);

create table if not exists course_progress (
  course_id uuid not null references courses(id) on delete cascade,
  lesson_date date not null,
  status text not null default 'planned',
  note text not null default '',
  version integer not null default 1,
  updated_at timestamptz not null default now(),
  primary key (course_id, lesson_date)
);

create table if not exists device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  platform text not null,
  provider text not null,
  token text not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists device_tokens_user_idx on device_tokens(user_id);

create table if not exists user_preferences (
  user_id uuid primary key references users(id) on delete cascade,
  locale text not null default 'zh-CN',
  timezone_id text not null default 'Asia/Shanghai',
  course_reminders_enabled boolean not null default true,
  updated_at timestamptz not null default now()
);

create table if not exists news_items (
  id uuid primary key,
  source text not null,
  source_url text not null,
  title text not null,
  summary text not null default '',
  language text not null default 'zh-CN',
  published_at timestamptz,
  fetched_at timestamptz not null default now(),
  unique (source, source_url)
);

create table if not exists sync_conflicts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  entity_type text not null,
  entity_id uuid not null,
  local_payload jsonb not null,
  remote_payload jsonb not null,
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

create index if not exists sync_conflicts_user_open_idx
  on sync_conflicts(user_id, created_at) where resolved_at is null;
