-- Facility detail metadata used by the two-sport beta experience.
-- Google Places enrichment can safely populate these columns from an Edge
-- Function without exposing the provider key to the iOS client.
begin;

alter table public.courts
  add column if not exists description text not null default '',
  add column if not exists booking_url text;

drop function if exists public.nearby_courts_and_clubs(public.sport_code, double precision, integer);

create function public.nearby_courts_and_clubs(
  p_sport public.sport_code,
  p_radius_miles double precision default 25,
  p_limit integer default 100
) returns table (
  court_id uuid, club_id uuid, name text, description text, address text,
  city text, distance_miles double precision, latitude double precision,
  longitude double precision, member_count bigint, group_count bigint,
  is_member boolean, website_url text, booking_url text
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
  select n.id, cl.id, coalesce(cl.name, n.name),
    coalesce(nullif(cl.description, ''), nullif(n.description, ''),
      'A nearby ' || initcap(p_sport::text) || ' facility.'),
    n.address, n.city,
    round(n.miles::numeric, 1)::double precision,
    round(n.latitude::numeric, 3)::double precision,
    round(n.longitude::numeric, 3)::double precision,
    (select count(*) from public.club_memberships cm where cm.club_id = cl.id),
    (select count(*) from public.community_groups g where g.club_id = cl.id),
    exists(select 1 from public.club_memberships cm where cm.club_id = cl.id and cm.user_id = auth.uid()),
    n.website_url,
    n.booking_url
  from nearby n left join public.clubs cl
    on cl.court_id = n.id and cl.sport = p_sport and cl.is_public
  where n.miles <= least(greatest(coalesce(p_radius_miles, 25), 1), 100)
  order by n.miles, cl.id nulls last, n.name
  limit least(greatest(coalesce(p_limit, 100), 1), 200);
$$;

revoke all on function public.nearby_courts_and_clubs(public.sport_code, double precision, integer) from public, anon;
grant execute on function public.nearby_courts_and_clubs(public.sport_code, double precision, integer) to authenticated;

commit;
