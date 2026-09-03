-- Birth date is private. Other users receive age only through scoped discovery RPCs.
begin;

create or replace function public.my_profile()
returns table (
  id uuid, username text, display_name text, birth_date date, gender public.gender_code,
  avatar_id text, bio text, city text, discovery_radius_miles smallint,
  is_discoverable boolean, onboarding_completed_at timestamptz,
  created_at timestamptz, updated_at timestamptz
) language sql stable security definer set search_path = '' as $$
  select p.id, p.username, p.display_name, p.birth_date, p.gender, p.avatar_id,
    p.bio, p.city, p.discovery_radius_miles, p.is_discoverable,
    p.onboarding_completed_at, p.created_at, p.updated_at
  from public.profiles p where p.id = auth.uid();
$$;

revoke select on public.profiles from authenticated;
grant select (
  id, username, display_name, gender, avatar_id, bio, city,
  discovery_radius_miles, is_discoverable, onboarding_completed_at,
  created_at, updated_at
) on public.profiles to authenticated;
revoke all on function public.my_profile() from public;
grant execute on function public.my_profile() to authenticated;

commit;
