-- Keep news writes behind the service-role Edge Function. The Flutter client
-- reads the public digest endpoint, while authenticated users may inspect the
-- cached rows through normal RLS if needed.
alter table public.news_items enable row level security;
drop policy if exists "authenticated users read news" on public.news_items;
create policy "authenticated users read news"
  on public.news_items for select to authenticated using (true);
revoke insert, update, delete on public.news_items from anon, authenticated;

-- Keep one current snapshot per repository. Historical snapshots made the
-- digest repeat the same repository and kept stale scores indefinitely.
delete from public.news_items older
using public.news_items newer
where older.repository_full_name = newer.repository_full_name
  and (older.fetched_at, older.id) < (newer.fetched_at, newer.id);
alter table public.news_items
  drop constraint if exists news_items_repository_full_name_published_at_key;
create unique index if not exists news_items_repository_full_name_key
  on public.news_items(repository_full_name);

-- New accounts need a preference row before the daily cron can select them.
create or replace function public.create_default_user_preferences()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.user_preferences (user_id)
  values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_focus_flow on auth.users;
create trigger on_auth_user_created_focus_flow
  after insert on auth.users
  for each row execute function public.create_default_user_preferences();

insert into public.user_preferences (user_id)
select id from auth.users
on conflict (user_id) do nothing;

create or replace function public.claim_device_token(
  p_platform text,
  p_provider text,
  p_token text
)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if p_platform not in ('android', 'ios') then
    raise exception 'Unsupported platform';
  end if;
  if p_provider not in ('fcm', 'apns', 'hms') then
    raise exception 'Unsupported push provider';
  end if;
  if char_length(p_token) < 8 then
    raise exception 'Invalid device token';
  end if;
  if not exists (
    select 1 from public.device_tokens
    where user_id = auth.uid() and token = p_token and invalid_at is null
  ) and (
    select count(*) from public.device_tokens
    where user_id = auth.uid() and invalid_at is null
  ) >= 20 then
    raise exception 'Device token limit exceeded';
  end if;

  insert into public.device_tokens (
    user_id, platform, provider, token, last_seen_at, invalid_at
  ) values (
    auth.uid(), p_platform, p_provider, p_token, now(), null
  )
  on conflict (token) do update set
    user_id = excluded.user_id,
    platform = excluded.platform,
    provider = excluded.provider,
    last_seen_at = excluded.last_seen_at,
    invalid_at = null;
end;
$$;

create or replace function public.revoke_device_token(p_token text)
returns void
language sql
security definer set search_path = public
as $$
  delete from public.device_tokens
  where token = p_token and user_id = auth.uid();
$$;

revoke all on function public.claim_device_token(text, text, text) from public;
revoke all on function public.revoke_device_token(text) from public;
grant execute on function public.claim_device_token(text, text, text) to authenticated;
grant execute on function public.revoke_device_token(text) to authenticated;

-- Entity writes use an atomic version check. A client may create version 1 or
-- replace exactly the version it previously read; stale devices receive a
-- conflict response instead of overwriting a newer row.
create or replace function public.sync_task_cas(p_task jsonb)
returns jsonb
language plpgsql
security definer set search_path = public
as $$
declare
  current_task public.tasks%rowtype;
  requested_id uuid;
  requested_version bigint;
  requested_base_version bigint;
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null then
    raise exception 'Authentication required';
  end if;
  requested_id := (p_task->>'id')::uuid;
  requested_version := (p_task->>'version')::bigint;
  requested_base_version := (p_task->>'base_version')::bigint;

  select * into current_task
  from public.tasks
  where id = requested_id
  for update;

  if not found then
    if requested_base_version <> 0 or requested_version < 1 then
      return jsonb_build_object('status', 'conflict', 'remote', null);
    end if;
    insert into public.tasks (
      id, user_id, title, description, start_at, end_at, timezone_id,
      repeat_rule, reminder_minutes, status, priority, version,
      created_at, updated_at, deleted_at
    ) values (
      requested_id,
      current_user_id,
      p_task->>'title',
      coalesce(p_task->>'description', ''),
      (p_task->>'start_at')::timestamptz,
      (p_task->>'end_at')::timestamptz,
      p_task->>'timezone_id',
      coalesce(p_task->'repeat_rule', '{"type":"none"}'::jsonb),
      coalesce((p_task->>'reminder_minutes')::integer, 0),
      coalesce(p_task->>'status', 'planned'),
      coalesce((p_task->>'priority')::smallint, 2),
      requested_version,
      (p_task->>'created_at')::timestamptz,
      (p_task->>'updated_at')::timestamptz,
      nullif(p_task->>'deleted_at', '')::timestamptz
    ) on conflict (id) do nothing;
    if not found then
      return jsonb_build_object('status', 'conflict', 'remote', null);
    end if;
    return jsonb_build_object('status', 'accepted', 'version', requested_version);
  end if;

  if current_task.user_id <> current_user_id then
    return jsonb_build_object('status', 'conflict', 'remote', null);
  end if;
  if requested_base_version <> current_task.version
     or requested_version <= requested_base_version then
    return jsonb_build_object(
      'status', 'conflict',
      'remote', to_jsonb(current_task) - 'user_id'
    );
  end if;

  update public.tasks set
    title = p_task->>'title',
    description = coalesce(p_task->>'description', ''),
    start_at = (p_task->>'start_at')::timestamptz,
    end_at = (p_task->>'end_at')::timestamptz,
    timezone_id = p_task->>'timezone_id',
    repeat_rule = coalesce(p_task->'repeat_rule', '{"type":"none"}'::jsonb),
    reminder_minutes = coalesce((p_task->>'reminder_minutes')::integer, 0),
    status = coalesce(p_task->>'status', 'planned'),
    priority = coalesce((p_task->>'priority')::smallint, 2),
    version = requested_version,
    updated_at = (p_task->>'updated_at')::timestamptz,
    deleted_at = nullif(p_task->>'deleted_at', '')::timestamptz
  where id = requested_id and user_id = current_user_id;
  return jsonb_build_object('status', 'accepted', 'version', requested_version);
end;
$$;

create or replace function public.sync_note_cas(p_note jsonb)
returns jsonb
language plpgsql
security definer set search_path = public
as $$
declare
  current_note public.notes%rowtype;
  requested_id uuid;
  requested_version bigint;
  requested_base_version bigint;
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null then
    raise exception 'Authentication required';
  end if;
  requested_id := (p_note->>'id')::uuid;
  requested_version := (p_note->>'version')::bigint;
  requested_base_version := (p_note->>'base_version')::bigint;

  select * into current_note
  from public.notes
  where id = requested_id
  for update;

  if not found then
    if requested_base_version <> 0 or requested_version < 1 then
      return jsonb_build_object('status', 'conflict', 'remote', null);
    end if;
    insert into public.notes (
      id, user_id, title, body_markdown, tags, is_favorite, version,
      created_at, updated_at, deleted_at
    ) values (
      requested_id,
      current_user_id,
      p_note->>'title',
      coalesce(p_note->>'body_markdown', ''),
      array(select jsonb_array_elements_text(coalesce(p_note->'tags', '[]'::jsonb))),
      coalesce((p_note->>'is_favorite')::boolean, false),
      requested_version,
      (p_note->>'created_at')::timestamptz,
      (p_note->>'updated_at')::timestamptz,
      nullif(p_note->>'deleted_at', '')::timestamptz
    ) on conflict (id) do nothing;
    if not found then
      return jsonb_build_object('status', 'conflict', 'remote', null);
    end if;
    return jsonb_build_object('status', 'accepted', 'version', requested_version);
  end if;

  if current_note.user_id <> current_user_id then
    return jsonb_build_object('status', 'conflict', 'remote', null);
  end if;
  if requested_base_version <> current_note.version
     or requested_version <= requested_base_version then
    return jsonb_build_object(
      'status', 'conflict',
      'remote', to_jsonb(current_note) - 'user_id'
    );
  end if;

  update public.notes set
    title = p_note->>'title',
    body_markdown = coalesce(p_note->>'body_markdown', ''),
    tags = array(select jsonb_array_elements_text(coalesce(p_note->'tags', '[]'::jsonb))),
    is_favorite = coalesce((p_note->>'is_favorite')::boolean, false),
    version = requested_version,
    updated_at = (p_note->>'updated_at')::timestamptz,
    deleted_at = nullif(p_note->>'deleted_at', '')::timestamptz
  where id = requested_id and user_id = current_user_id;
  return jsonb_build_object('status', 'accepted', 'version', requested_version);
end;
$$;

revoke all on function public.sync_task_cas(jsonb) from public;
revoke all on function public.sync_note_cas(jsonb) from public;
grant execute on function public.sync_task_cas(jsonb) to authenticated;
grant execute on function public.sync_note_cas(jsonb) to authenticated;

create table if not exists public.digest_deliveries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  digest_date date not null,
  provider text not null check (provider in ('fcm', 'apns', 'hms')),
  token_fingerprint text not null,
  status text not null default 'pending'
    check (status in ('pending', 'sent', 'failed')),
  attempt_count integer not null default 1,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, digest_date, provider, token_fingerprint)
);

alter table public.digest_deliveries enable row level security;
revoke all on public.digest_deliveries from anon, authenticated;

create or replace function public.claim_digest_delivery(
  p_user_id uuid,
  p_digest_date date,
  p_provider text,
  p_token_fingerprint text
)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  claimed_id uuid;
begin
  if p_provider not in ('fcm', 'apns', 'hms') then
    raise exception 'Unsupported push provider';
  end if;
  insert into public.digest_deliveries (
    user_id, digest_date, provider, token_fingerprint
  ) values (
    p_user_id, p_digest_date, p_provider, p_token_fingerprint
  )
  on conflict (user_id, digest_date, provider, token_fingerprint)
  do update set
    status = 'pending',
    attempt_count = public.digest_deliveries.attempt_count + 1,
    last_error = null,
    updated_at = now()
  where public.digest_deliveries.status = 'failed'
     or (
       public.digest_deliveries.status = 'pending'
       and public.digest_deliveries.updated_at < now() - interval '10 minutes'
     )
  returning id into claimed_id;
  return claimed_id;
end;
$$;

revoke all on function public.claim_digest_delivery(uuid, date, text, text)
  from public;
grant execute on function public.claim_digest_delivery(uuid, date, text, text)
  to service_role;
