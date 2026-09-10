-- Allow the map to zoom from a local view to country-scale discovery while
-- continuing to expose only neighborhood-rounded coordinates.
begin;

drop function if exists public.find_nearby_players(public.sport_code, double precision, integer);
create function public.find_nearby_players(
  p_sport public.sport_code,
  p_radius_miles double precision default 25,
  p_limit integer default 500
) returns table (
  id uuid, username text, display_name text, gender public.gender_code,
  age_years integer, avatar_id text, bio text, city text,
  distance_miles double precision,
  approximate_latitude double precision,
  approximate_longitude double precision,
  sport public.sport_code, rating numeric, uncertainty numeric,
  matches_played integer, wins integer, losses integer, draws integer,
  rating_opt_out boolean, partner_status text, home_court text,
  owns_equipment boolean, played_tournaments boolean,
  self_assessment text, social_skill_label text
)
language sql stable security definer set search_path = ''
as $$
  with me as (
    select l.latitude, l.longitude
    from public.profile_locations l where l.user_id = auth.uid()
  ), candidates as (
    select p.*, sp.*,
      l.latitude as candidate_latitude, l.longitude as candidate_longitude,
      3958.7613 * 2 * asin(sqrt(
        power(sin(radians(l.latitude - me.latitude) / 2), 2) +
        cos(radians(me.latitude)) * cos(radians(l.latitude)) *
        power(sin(radians(l.longitude - me.longitude) / 2), 2)
      )) as miles
    from me
    join public.profile_locations l on l.user_id <> auth.uid()
    join public.profiles p on p.id = l.user_id and p.is_discoverable
    join public.sport_profiles sp on sp.user_id = p.id and sp.sport = p_sport and sp.is_active
    where not exists (
      select 1 from public.blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = p.id)
         or (b.blocker_id = p.id and b.blocked_id = auth.uid())
    )
  )
  select c.id, c.username, c.display_name, c.gender,
    case when c.birth_date is null then null else extract(year from age(current_date,c.birth_date))::integer end,
    c.avatar_id, c.bio, c.city, round(c.miles::numeric,1)::double precision,
    round(c.candidate_latitude::numeric,2)::double precision,
    round(c.candidate_longitude::numeric,2)::double precision,
    c.sport, c.rating, c.uncertainty, c.matches_played, c.wins, c.losses, c.draws,
    c.rating_opt_out, c.partner_status, c.home_court, c.owns_equipment,
    c.played_tournaments, c.self_assessment, c.social_skill_label
  from candidates c
  where c.miles <= least(greatest(coalesce(p_radius_miles,25),1),3000)
  order by c.miles, c.display_name
  limit least(greatest(coalesce(p_limit,500),1),1000);
$$;

revoke all on function public.find_nearby_players(public.sport_code,double precision,integer) from public, anon;
grant execute on function public.find_nearby_players(public.sport_code,double precision,integer) to authenticated;
comment on function public.find_nearby_players(public.sport_code,double precision,integer) is
  'Returns players within up to 3,000 miles with neighborhood-rounded coordinates; exact coordinates remain private.';

commit;
