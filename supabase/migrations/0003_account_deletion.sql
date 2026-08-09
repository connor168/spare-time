-- Allow authenticated users to delete their own account and cascade data.

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null then
    raise exception 'Authentication required';
  end if;

  -- Cascading deletes are handled by FK constraints (on delete cascade),
  -- but we explicitly clean up non-cascaded tables and leave an audit trace.

  delete from public.digest_deliveries where user_id = current_user_id;
  delete from public.device_tokens where user_id = current_user_id;
  delete from public.tasks where user_id = current_user_id;
  delete from public.notes where user_id = current_user_id;
  delete from public.user_preferences where user_id = current_user_id;

  -- Finally delete the auth user record (requires superuser or service_role,
  -- so this function must be called via the service_role key).
  delete from auth.users where id = current_user_id;
end;
$$;

revoke all on function public.delete_my_account() from public;
grant execute on function public.delete_my_account() to authenticated;

-- Export helper: return all user data as a single JSON object.
create or replace function public.export_my_data()
returns jsonb
language plpgsql
security definer set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null then
    raise exception 'Authentication required';
  end if;
  return jsonb_build_object(
    'tasks', coalesce((
      select jsonb_agg(row_to_json(t))
      from public.tasks t
      where t.user_id = current_user_id
    ), '[]'::jsonb),
    'notes', coalesce((
      select jsonb_agg(row_to_json(n))
      from public.notes n
      where n.user_id = current_user_id
    ), '[]'::jsonb),
    'preferences', coalesce((
      select row_to_json(p)
      from public.user_preferences p
      where p.user_id = current_user_id
    ), null::jsonb)
  );
end;
$$;

revoke all on function public.export_my_data() from public;
grant execute on function public.export_my_data() to authenticated;
