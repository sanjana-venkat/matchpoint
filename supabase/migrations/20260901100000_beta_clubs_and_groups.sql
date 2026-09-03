-- Two-sport beta community directory: nearby courts, clubs, memberships, and groups.
begin;

create table if not exists public.courts (
  id uuid primary key default gen_random_uuid(),
  external_source text not null default 'apple_maps',
  external_id text not null,
  name text not null check (length(name) between 1 and 160),
  address text not null default '',
  city text not null default '',
  region text not null default '',
  postal_code text not null default '',
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  sports public.sport_code[] not null default array[]::public.sport_code[],
  court_count integer check (court_count is null or court_count >= 0),
  is_indoor boolean,
  website_url text,
  phone text,
  last_verified_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (external_source, external_id)
);

create table if not exists public.clubs (
  id uuid primary key default gen_random_uuid(),
  sport public.sport_code not null check (sport in ('pickleball', 'badminton')),
  court_id uuid references public.courts(id) on delete set null,
  created_by uuid not null references public.profiles(id) on delete restrict,
  name text not null check (length(name) between 2 and 80),
  description text not null default '' check (length(description) <= 1000),
  is_public boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.club_memberships (
  club_id uuid not null references public.clubs(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'moderator', 'member')),
  joined_at timestamptz not null default now(),
  primary key (club_id, user_id)
);

create table if not exists public.community_groups (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  created_by uuid not null references public.profiles(id) on delete restrict,
  name text not null check (length(name) between 2 and 80),
  description text not null default '' check (length(description) <= 1000),
  max_members integer check (max_members is null or max_members between 2 and 200),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.community_group_members (
  group_id uuid not null references public.community_groups(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'moderator', 'member')),
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

create index if not exists courts_location_index on public.courts (latitude, longitude);
create index if not exists clubs_sport_court_index on public.clubs (sport, court_id);
create index if not exists club_memberships_user_index on public.club_memberships (user_id, club_id);
create index if not exists community_groups_club_index on public.community_groups (club_id, created_at);
create index if not exists community_group_members_user_index on public.community_group_members (user_id, group_id);

alter table public.courts enable row level security;
alter table public.clubs enable row level security;
alter table public.club_memberships enable row level security;
alter table public.community_groups enable row level security;
alter table public.community_group_members enable row level security;

drop policy if exists "authenticated users view courts" on public.courts;
create policy "authenticated users view courts" on public.courts for select to authenticated using (true);
drop policy if exists "authenticated users view public clubs" on public.clubs;
create policy "authenticated users view public clubs" on public.clubs for select to authenticated
using (is_public or created_by = (select auth.uid()) or exists (
  select 1 from public.club_memberships cm where cm.club_id = clubs.id and cm.user_id = (select auth.uid())
));
drop policy if exists "authenticated users view club memberships" on public.club_memberships;
create policy "authenticated users view club memberships" on public.club_memberships for select to authenticated
using (exists (select 1 from public.clubs c where c.id = club_id and c.is_public) or user_id = (select auth.uid()));
drop policy if exists "authenticated users view community groups" on public.community_groups;
create policy "authenticated users view community groups" on public.community_groups for select to authenticated
using (exists (select 1 from public.clubs c where c.id = club_id and (c.is_public or c.created_by = (select auth.uid()))));
drop policy if exists "authenticated users view group memberships" on public.community_group_members;
create policy "authenticated users view group memberships" on public.community_group_members for select to authenticated
using (exists (
  select 1 from public.community_groups g join public.clubs c on c.id = g.club_id
  where g.id = group_id and (c.is_public or c.created_by = (select auth.uid()))
));

revoke all on public.courts, public.clubs, public.club_memberships,
  public.community_groups, public.community_group_members from anon;
revoke insert, update, delete on public.courts, public.clubs, public.club_memberships,
  public.community_groups, public.community_group_members from authenticated;
grant select on public.courts, public.clubs, public.club_memberships,
  public.community_groups, public.community_group_members to authenticated;

create or replace function public.sync_discovered_courts(p_courts jsonb)
returns integer language plpgsql security definer set search_path = '' as $$
declare v_item jsonb; v_count integer := 0; v_sports public.sport_code[];
begin
  if jsonb_typeof(p_courts) <> 'array' or jsonb_array_length(p_courts) > 50 then
    raise exception 'invalid court batch';
  end if;
  for v_item in select value from jsonb_array_elements(p_courts) loop
    select coalesce(array_agg(value::public.sport_code), array[]::public.sport_code[])
      into v_sports
      from jsonb_array_elements_text(coalesce(v_item->'sports', '[]'::jsonb))
      where value in ('pickleball', 'badminton');
    if coalesce(v_item->>'external_id', '') = '' or coalesce(v_item->>'name', '') = '' then continue; end if;
    insert into public.courts (
      external_source, external_id, name, address, city, region, postal_code,
      latitude, longitude, sports, website_url, phone, last_verified_at, updated_at
    ) values (
      'apple_maps', left(v_item->>'external_id', 240), left(v_item->>'name', 160),
      left(coalesce(v_item->>'address', ''), 300), left(coalesce(v_item->>'city', ''), 100),
      left(coalesce(v_item->>'region', ''), 100), left(coalesce(v_item->>'postal_code', ''), 24),
      (v_item->>'latitude')::double precision, (v_item->>'longitude')::double precision,
      v_sports, left(v_item->>'website_url', 500), left(v_item->>'phone', 40), now(), now()
    ) on conflict (external_source, external_id) do update set
      name = excluded.name, address = excluded.address, city = excluded.city,
      region = excluded.region, postal_code = excluded.postal_code,
      latitude = excluded.latitude, longitude = excluded.longitude,
      sports = (select array_agg(distinct s) from unnest(public.courts.sports || excluded.sports) s),
      website_url = coalesce(excluded.website_url, public.courts.website_url),
      phone = coalesce(excluded.phone, public.courts.phone), last_verified_at = now(), updated_at = now();
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

create or replace function public.nearby_courts_and_clubs(
  p_sport public.sport_code,
  p_radius_miles double precision default 25,
  p_limit integer default 100
) returns table (
  court_id uuid, club_id uuid, name text, description text, address text,
  city text, distance_miles double precision, latitude double precision,
  longitude double precision, member_count bigint, group_count bigint, is_member boolean
) language sql stable security definer set search_path = '' as $$
  with me as (
    select latitude, longitude from public.profile_locations where user_id = auth.uid()
  ), nearby as (
    select c.*,
      3958.7613 * 2 * asin(sqrt(
        power(sin(radians(c.latitude - me.latitude) / 2), 2) +
        cos(radians(me.latitude)) * cos(radians(c.latitude)) *
        power(sin(radians(c.longitude - me.longitude) / 2), 2)
      )) as miles
    from public.courts c cross join me where p_sport = any(c.sports)
  )
  select n.id, cl.id, coalesce(cl.name, n.name), coalesce(cl.description, ''), n.address,
    n.city, round(n.miles::numeric, 1)::double precision, round(n.latitude::numeric, 3)::double precision,
    round(n.longitude::numeric, 3)::double precision,
    (select count(*) from public.club_memberships cm where cm.club_id = cl.id),
    (select count(*) from public.community_groups g where g.club_id = cl.id),
    exists(select 1 from public.club_memberships cm where cm.club_id = cl.id and cm.user_id = auth.uid())
  from nearby n left join public.clubs cl on cl.court_id = n.id and cl.sport = p_sport and cl.is_public
  where n.miles <= least(greatest(coalesce(p_radius_miles, 25), 1), 100)
  order by n.miles, cl.id nulls last, n.name
  limit least(greatest(coalesce(p_limit, 100), 1), 200);
$$;

create or replace function public.create_club(
  p_sport public.sport_code, p_court_id uuid, p_name text, p_description text default ''
) returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid;
begin
  if p_sport not in ('pickleball', 'badminton') then raise exception 'sport is coming soon'; end if;
  if not exists (select 1 from public.courts where id = p_court_id and p_sport = any(sports)) then raise exception 'court not found'; end if;
  insert into public.clubs(sport, court_id, created_by, name, description)
  values (p_sport, p_court_id, auth.uid(), trim(p_name), trim(coalesce(p_description, ''))) returning id into v_id;
  insert into public.club_memberships(club_id, user_id, role) values (v_id, auth.uid(), 'owner');
  return v_id;
end;
$$;

create or replace function public.set_club_membership(p_club_id uuid, p_join boolean)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if p_join then
    if not exists (select 1 from public.clubs where id = p_club_id and is_public) then raise exception 'club not found'; end if;
    insert into public.club_memberships(club_id, user_id) values (p_club_id, auth.uid()) on conflict do nothing;
  else
    delete from public.club_memberships where club_id = p_club_id and user_id = auth.uid() and role <> 'owner';
  end if;
end;
$$;

create or replace function public.club_members(p_club_id uuid)
returns table (id uuid, display_name text, username text, avatar_id text, role text)
language sql stable security definer set search_path = '' as $$
  select p.id, p.display_name, p.username, p.avatar_id, cm.role
  from public.club_memberships cm join public.profiles p on p.id = cm.user_id
  join public.clubs c on c.id = cm.club_id
  where cm.club_id = p_club_id and (c.is_public or exists (
    select 1 from public.club_memberships mine where mine.club_id = c.id and mine.user_id = auth.uid()
  )) order by case cm.role when 'owner' then 0 when 'moderator' then 1 else 2 end, cm.joined_at;
$$;

create or replace function public.club_groups(p_club_id uuid)
returns table (id uuid, name text, description text, member_count bigint, is_member boolean)
language sql stable security definer set search_path = '' as $$
  select g.id, g.name, g.description,
    (select count(*) from public.community_group_members gm where gm.group_id = g.id),
    exists(select 1 from public.community_group_members gm where gm.group_id = g.id and gm.user_id = auth.uid())
  from public.community_groups g join public.clubs c on c.id = g.club_id
  where g.club_id = p_club_id and (c.is_public or exists (
    select 1 from public.club_memberships mine where mine.club_id = c.id and mine.user_id = auth.uid()
  )) order by g.created_at desc;
$$;

create or replace function public.create_community_group(
  p_club_id uuid, p_name text, p_description text default '', p_max_members integer default null
) returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid;
begin
  if not exists (select 1 from public.club_memberships where club_id = p_club_id and user_id = auth.uid()) then
    raise exception 'join the club before creating a group';
  end if;
  insert into public.community_groups(club_id, created_by, name, description, max_members)
  values (p_club_id, auth.uid(), trim(p_name), trim(coalesce(p_description, '')), p_max_members) returning id into v_id;
  insert into public.community_group_members(group_id, user_id, role) values (v_id, auth.uid(), 'owner');
  return v_id;
end;
$$;

create or replace function public.set_community_group_membership(p_group_id uuid, p_join boolean)
returns void language plpgsql security definer set search_path = '' as $$
declare v_club_id uuid; v_max integer; v_count integer;
begin
  select club_id, max_members into v_club_id, v_max from public.community_groups where id = p_group_id;
  if v_club_id is null then raise exception 'group not found'; end if;
  if p_join then
    if not exists (select 1 from public.club_memberships where club_id = v_club_id and user_id = auth.uid()) then
      raise exception 'join the club first';
    end if;
    select count(*) into v_count from public.community_group_members where group_id = p_group_id;
    if v_max is not null and v_count >= v_max then raise exception 'group is full'; end if;
    insert into public.community_group_members(group_id, user_id) values (p_group_id, auth.uid()) on conflict do nothing;
  else
    delete from public.community_group_members where group_id = p_group_id and user_id = auth.uid() and role <> 'owner';
  end if;
end;
$$;

revoke all on function public.sync_discovered_courts(jsonb) from public;
revoke all on function public.nearby_courts_and_clubs(public.sport_code, double precision, integer) from public;
revoke all on function public.create_club(public.sport_code, uuid, text, text) from public;
revoke all on function public.set_club_membership(uuid, boolean) from public;
revoke all on function public.club_members(uuid) from public;
revoke all on function public.club_groups(uuid) from public;
revoke all on function public.create_community_group(uuid, text, text, integer) from public;
revoke all on function public.set_community_group_membership(uuid, boolean) from public;
grant execute on function public.sync_discovered_courts(jsonb) to authenticated;
grant execute on function public.nearby_courts_and_clubs(public.sport_code, double precision, integer) to authenticated;
grant execute on function public.create_club(public.sport_code, uuid, text, text) to authenticated;
grant execute on function public.set_club_membership(uuid, boolean) to authenticated;
grant execute on function public.club_members(uuid) to authenticated;
grant execute on function public.club_groups(uuid) to authenticated;
grant execute on function public.create_community_group(uuid, text, text, integer) to authenticated;
grant execute on function public.set_community_group_membership(uuid, boolean) to authenticated;

commit;
