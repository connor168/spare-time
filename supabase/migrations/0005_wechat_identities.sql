-- External identities are managed only by the wechat-login Edge Function.
create table if not exists public.oauth_identities (
  provider text not null,
  subject text not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  profile jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (provider, subject),
  constraint oauth_identities_provider_check check (provider in ('wechat'))
);

create unique index if not exists oauth_identities_provider_user_idx
  on public.oauth_identities(provider, user_id);

alter table public.oauth_identities enable row level security;
revoke all on public.oauth_identities from anon, authenticated;
