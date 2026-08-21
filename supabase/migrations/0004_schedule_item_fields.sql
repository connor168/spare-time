-- Extend tasks into schedule items while preserving existing task rows.

alter table public.tasks
  add column if not exists kind text not null default 'task',
  add column if not exists location text not null default '',
  add column if not exists reminder_enabled boolean not null default true;

alter table public.tasks
  drop constraint if exists tasks_kind_check,
  drop constraint if exists tasks_status_check;

alter table public.tasks
  add constraint tasks_kind_check
    check (kind in ('task', 'course', 'time_block')),
  add constraint tasks_status_check
    check (status in ('planned', 'completed', 'today_incomplete'));

alter table public.tasks
  alter column reminder_minutes set default 5;

-- Keep the compare-and-swap sync endpoint in step with the new columns.
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
      id, user_id, title, description, kind, location, start_at, end_at,
      timezone_id, repeat_rule, reminder_minutes, reminder_enabled, status,
      priority, version, created_at, updated_at, deleted_at
    ) values (
      requested_id,
      current_user_id,
      p_task->>'title',
      coalesce(p_task->>'description', ''),
      coalesce(p_task->>'kind', 'task'),
      coalesce(p_task->>'location', ''),
      (p_task->>'start_at')::timestamptz,
      (p_task->>'end_at')::timestamptz,
      p_task->>'timezone_id',
      coalesce(p_task->'repeat_rule', '{"type":"none"}'::jsonb),
      coalesce((p_task->>'reminder_minutes')::integer, 5),
      coalesce((p_task->>'reminder_enabled')::boolean, true),
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
    kind = coalesce(p_task->>'kind', 'task'),
    location = coalesce(p_task->>'location', ''),
    start_at = (p_task->>'start_at')::timestamptz,
    end_at = (p_task->>'end_at')::timestamptz,
    timezone_id = p_task->>'timezone_id',
    repeat_rule = coalesce(p_task->'repeat_rule', '{"type":"none"}'::jsonb),
    reminder_minutes = coalesce((p_task->>'reminder_minutes')::integer, 5),
    reminder_enabled = coalesce((p_task->>'reminder_enabled')::boolean, true),
    status = coalesce(p_task->>'status', 'planned'),
    priority = coalesce((p_task->>'priority')::smallint, 2),
    version = requested_version,
    updated_at = (p_task->>'updated_at')::timestamptz,
    deleted_at = nullif(p_task->>'deleted_at', '')::timestamptz
  where id = requested_id and user_id = current_user_id;
  return jsonb_build_object('status', 'accepted', 'version', requested_version);
end;
$$;

revoke all on function public.sync_task_cas(jsonb) from public;
grant execute on function public.sync_task_cas(jsonb) to authenticated;
