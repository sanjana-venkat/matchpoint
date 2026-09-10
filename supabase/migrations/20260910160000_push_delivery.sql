-- APNs device registration and auditable delivery state.
-- Push credentials stay in Edge Function secrets and never enter Postgres.

delete from public.device_tokens a
using public.device_tokens b
where a.token = b.token
  and a.last_seen_at < b.last_seen_at;

create unique index if not exists device_tokens_token_unique
  on public.device_tokens(token);

create table if not exists public.push_deliveries (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid not null references public.notifications(id) on delete cascade,
  device_token_id uuid references public.device_tokens(id) on delete set null,
  status text not null check (status in ('sent', 'failed', 'invalid_token')),
  apns_status integer,
  error text,
  attempted_at timestamptz not null default now(),
  unique (notification_id, device_token_id)
);

alter table public.push_deliveries enable row level security;
revoke all on public.push_deliveries from anon, authenticated;

create or replace function public.register_device_token(
  p_token text,
  p_environment text default 'production'
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_token text := lower(trim(p_token));
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_environment not in ('development', 'production') then
    raise exception 'Invalid APNs environment';
  end if;
  if v_token !~ '^[0-9a-f]{64,200}$' then
    raise exception 'Invalid APNs device token';
  end if;

  insert into public.device_tokens(user_id, token, platform, environment, last_seen_at)
  values(auth.uid(), v_token, 'ios', p_environment, now())
  on conflict (token) do update
    set user_id = excluded.user_id,
        platform = excluded.platform,
        environment = excluded.environment,
        last_seen_at = now();
end;
$$;

create or replace function public.unregister_device_token(p_token text)
returns void
language sql
security invoker
set search_path = ''
as $$
  delete from public.device_tokens
  where user_id = auth.uid() and token = lower(trim(p_token));
$$;

revoke all on function public.register_device_token(text,text) from public;
revoke all on function public.unregister_device_token(text) from public;
grant execute on function public.register_device_token(text,text) to authenticated;
grant execute on function public.unregister_device_token(text) to authenticated;

comment on table public.push_deliveries is
  'Service-role-only APNs delivery attempts used for idempotency and diagnostics.';
