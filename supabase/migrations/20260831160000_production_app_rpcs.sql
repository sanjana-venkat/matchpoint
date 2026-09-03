-- Production application operations and privacy-safe nearby discovery.
begin;

-- Exact coordinates are private data and must never be returned by profile reads.
create table if not exists public.profile_locations (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  horizontal_accuracy_meters double precision check (horizontal_accuracy_meters is null or horizontal_accuracy_meters >= 0),
  captured_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.challenges add column if not exists rating_exempt boolean not null default false;
alter table public.profile_locations enable row level security;
drop policy if exists "users view own exact location" on public.profile_locations;
create policy "users view own exact location" on public.profile_locations
for select to authenticated using (user_id = (select auth.uid()));

-- Move any legacy coordinates into the private table, then erase the public copy.
insert into public.profile_locations (user_id, latitude, longitude)
select id, latitude, longitude from public.profiles
where latitude is not null and longitude is not null
on conflict (user_id) do update set
  latitude = excluded.latitude,
  longitude = excluded.longitude,
  updated_at = now();
update public.profiles set latitude = null, longitude = null
where latitude is not null or longitude is not null;
revoke select (latitude, longitude), update (latitude, longitude) on public.profiles from authenticated;
revoke all on public.profile_locations from anon, authenticated;
grant select on public.profile_locations to authenticated;

create or replace function public.update_my_location(
  p_latitude double precision,
  p_longitude double precision,
  p_horizontal_accuracy_meters double precision default null
) returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_latitude not between -90 and 90 or p_longitude not between -180 and 180 then
    raise exception 'invalid coordinates';
  end if;
  if p_horizontal_accuracy_meters is not null and p_horizontal_accuracy_meters < 0 then
    raise exception 'invalid accuracy';
  end if;
  insert into public.profile_locations (
    user_id, latitude, longitude, horizontal_accuracy_meters, captured_at, updated_at
  ) values (
    auth.uid(), p_latitude, p_longitude, p_horizontal_accuracy_meters, now(), now()
  ) on conflict (user_id) do update set
    latitude = excluded.latitude,
    longitude = excluded.longitude,
    horizontal_accuracy_meters = excluded.horizontal_accuracy_meters,
    captured_at = now(),
    updated_at = now();
end;
$$;

create or replace function public.clear_my_location()
returns void language sql security definer set search_path = '' as $$
  delete from public.profile_locations where user_id = auth.uid();
$$;

create or replace function public.find_nearby_players(
  p_sport public.sport_code,
  p_radius_miles double precision default 25,
  p_limit integer default 100
) returns table (
  id uuid,
  username text,
  display_name text,
  gender public.gender_code,
  age_years integer,
  avatar_id text,
  bio text,
  city text,
  distance_miles double precision,
  sport public.sport_code,
  rating numeric,
  uncertainty numeric,
  matches_played integer,
  wins integer,
  losses integer,
  draws integer,
  rating_opt_out boolean,
  partner_status text,
  home_court text,
  owns_equipment boolean,
  played_tournaments boolean,
  self_assessment text,
  social_skill_label text
)
language sql stable security definer set search_path = ''
as $$
  with me as (
    select l.latitude, l.longitude, p.discovery_radius_miles
    from public.profile_locations l
    join public.profiles p on p.id = l.user_id
    where l.user_id = auth.uid()
  ), candidates as (
    select p.*, sp.*,
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
    case when c.birth_date is null then null
         else extract(year from age(current_date, c.birth_date))::integer end,
    c.avatar_id, c.bio, c.city, round(c.miles::numeric, 1)::double precision,
    c.sport, c.rating, c.uncertainty, c.matches_played, c.wins, c.losses, c.draws,
    c.rating_opt_out, c.partner_status, c.home_court, c.owns_equipment,
    c.played_tournaments, c.self_assessment, c.social_skill_label
  from candidates c
  where c.miles <= least(greatest(coalesce(p_radius_miles, 25), 1), 100)
  order by c.miles, c.display_name
  limit least(greatest(coalesce(p_limit, 100), 1), 200);
$$;

create or replace function public.send_connection_request(p_recipient_id uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid;
begin
  if p_recipient_id = auth.uid() then raise exception 'cannot connect to yourself'; end if;
  if exists (select 1 from public.blocks where
      (blocker_id = auth.uid() and blocked_id = p_recipient_id) or
      (blocker_id = p_recipient_id and blocked_id = auth.uid())) then
    raise exception 'connection unavailable';
  end if;
  insert into public.connections (requester_id, recipient_id, status)
  values (auth.uid(), p_recipient_id, 'pending')
  on conflict (user_low, user_high) do update set
    requester_id = auth.uid(), recipient_id = p_recipient_id, status = 'pending',
    created_at = now(), responded_at = null
  returning id into v_id;
  insert into public.notifications(user_id, kind, payload)
  values (p_recipient_id, 'connection_request', jsonb_build_object('connection_id', v_id, 'from_user_id', auth.uid()));
  return v_id;
end;
$$;

create or replace function public.respond_connection_request(p_connection_id uuid, p_accept boolean)
returns void language plpgsql security definer set search_path = '' as $$
declare v_requester uuid;
begin
  update public.connections set
    status = case when p_accept then 'accepted'::public.connection_status else 'declined'::public.connection_status end,
    responded_at = now()
  where id = p_connection_id and recipient_id = auth.uid() and status = 'pending'
  returning requester_id into v_requester;
  if v_requester is null then raise exception 'pending request not found'; end if;
  insert into public.notifications(user_id, kind, payload)
  values (v_requester, case when p_accept then 'connection_accepted' else 'connection_declined' end,
          jsonb_build_object('connection_id', p_connection_id, 'user_id', auth.uid()));
end;
$$;

create or replace function public.set_player_blocked(p_player_id uuid, p_blocked boolean)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if p_player_id = auth.uid() then raise exception 'cannot block yourself'; end if;
  if p_blocked then
    insert into public.blocks(blocker_id, blocked_id) values (auth.uid(), p_player_id)
    on conflict do nothing;
    delete from public.connections
    where (requester_id = auth.uid() and recipient_id = p_player_id)
       or (requester_id = p_player_id and recipient_id = auth.uid());
  else
    delete from public.blocks where blocker_id = auth.uid() and blocked_id = p_player_id;
  end if;
end;
$$;

create or replace function public.create_conversation(
  p_sport public.sport_code,
  p_member_ids uuid[],
  p_title text default null
) returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid; v_member uuid; v_members uuid[];
begin
  select array_agg(distinct x) into v_members from unnest(coalesce(p_member_ids, array[]::uuid[]) || auth.uid()) x;
  if cardinality(v_members) < 2 or cardinality(v_members) > 30 then raise exception 'invalid member count'; end if;
  foreach v_member in array v_members loop
    if not exists (select 1 from public.profiles where id = v_member) then raise exception 'player not found'; end if;
    if exists (select 1 from public.blocks where
        (blocker_id = auth.uid() and blocked_id = v_member) or
        (blocker_id = v_member and blocked_id = auth.uid())) then raise exception 'conversation unavailable'; end if;
  end loop;
  if cardinality(v_members) = 2 then
    select c.id into v_id from public.conversations c
    where c.sport = p_sport and c.title is null
      and (select array_agg(cm.user_id order by cm.user_id) from public.conversation_members cm where cm.conversation_id = c.id)
        = (select array_agg(x order by x) from unnest(v_members) x)
    limit 1;
  end if;
  if v_id is null then
    insert into public.conversations(sport, title, created_by)
    values (p_sport, nullif(left(trim(p_title), 80), ''), auth.uid()) returning id into v_id;
    insert into public.conversation_members(conversation_id, user_id, accepted_at)
    select v_id, x, case when x = auth.uid() then now() else null end from unnest(v_members) x;
  end if;
  return v_id;
end;
$$;

create or replace function public.send_chat_message(
  p_conversation_id uuid,
  p_kind public.message_kind,
  p_body text default null,
  p_payload jsonb default '{}'::jsonb
) returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid; v_recipient uuid;
begin
  if not public.is_conversation_member(p_conversation_id) then raise exception 'not a conversation member'; end if;
  if coalesce(length(trim(p_body)), 0) = 0 and coalesce(p_payload, '{}'::jsonb) = '{}'::jsonb then
    raise exception 'message is empty';
  end if;
  if length(coalesce(p_body, '')) > 4000 then raise exception 'message is too long'; end if;
  insert into public.messages(conversation_id, sender_id, kind, body, payload)
  values (p_conversation_id, auth.uid(), p_kind, nullif(trim(p_body), ''), coalesce(p_payload, '{}'::jsonb))
  returning id into v_id;
  update public.conversations set updated_at = now() where id = p_conversation_id;
  for v_recipient in select user_id from public.conversation_members
      where conversation_id = p_conversation_id and user_id <> auth.uid() loop
    insert into public.notifications(user_id, kind, payload)
    values (v_recipient, 'message', jsonb_build_object('conversation_id', p_conversation_id, 'message_id', v_id, 'from_user_id', auth.uid()));
  end loop;
  return v_id;
end;
$$;

create or replace function public.create_challenge(
  p_sport public.sport_code,
  p_format public.match_format,
  p_participants jsonb,
  p_slots jsonb,
  p_note text default '',
  p_venue_name text default null,
  p_conversation_id uuid default null,
  p_rating_exempt boolean default false
) returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid; v_item jsonb; v_slot jsonb; v_user uuid; v_team smallint;
begin
  if jsonb_typeof(p_participants) <> 'array' or jsonb_array_length(p_participants) < 1 then raise exception 'participants required'; end if;
  if jsonb_typeof(p_slots) <> 'array' or jsonb_array_length(p_slots) < 1 or jsonb_array_length(p_slots) > 3 then raise exception 'one to three times required'; end if;
  if p_sport in ('volleyball','cricket','soccer') and p_format <> 'group' then raise exception 'group sport requires group format'; end if;
  if p_sport in ('pickleball','badminton','pingPong') and p_format = 'group' then raise exception 'invalid format'; end if;
  insert into public.challenges(conversation_id, created_by, sport, format, note, venue_name, rating_exempt)
  values (p_conversation_id, auth.uid(), p_sport, p_format, left(coalesce(p_note,''),1000), nullif(left(trim(p_venue_name),160),''), p_rating_exempt)
  returning id into v_id;
  insert into public.challenge_participants(challenge_id,user_id,team,accepted_at)
  values(v_id,auth.uid(),1,now());
  for v_item in select * from jsonb_array_elements(p_participants) loop
    v_user := (v_item->>'user_id')::uuid; v_team := (v_item->>'team')::smallint;
    if v_user = auth.uid() or v_team not in (1,2) then raise exception 'invalid participant'; end if;
    if exists(select 1 from public.blocks where (blocker_id=auth.uid() and blocked_id=v_user) or (blocker_id=v_user and blocked_id=auth.uid())) then raise exception 'participant unavailable'; end if;
    insert into public.challenge_participants(challenge_id,user_id,team) values(v_id,v_user,v_team);
    insert into public.notifications(user_id,kind,payload) values(v_user,'challenge',jsonb_build_object('challenge_id',v_id,'from_user_id',auth.uid()));
  end loop;
  for v_slot in select * from jsonb_array_elements(p_slots) loop
    insert into public.challenge_slots(challenge_id,starts_at,ends_at,proposed_by)
    values(v_id,(v_slot->>'starts_at')::timestamptz,(v_slot->>'ends_at')::timestamptz,auth.uid());
  end loop;
  return v_id;
end;
$$;

create or replace function public.respond_to_challenge(
  p_challenge_id uuid,
  p_accept boolean,
  p_selected_slot_id uuid default null
) returns uuid language plpgsql security definer set search_path = '' as $$
declare v_challenge public.challenges%rowtype; v_match_id uuid; v_all_accepted boolean;
begin
  select * into v_challenge from public.challenges where id=p_challenge_id for update;
  if v_challenge.id is null or v_challenge.status <> 'proposed' then raise exception 'challenge unavailable'; end if;
  update public.challenge_participants set
    accepted_at=case when p_accept then now() else null end,
    declined_at=case when p_accept then null else now() end
  where challenge_id=p_challenge_id and user_id=auth.uid();
  if not found then raise exception 'not a participant'; end if;
  if not p_accept then update public.challenges set status='cancelled' where id=p_challenge_id; return null; end if;
  if p_selected_slot_id is not null and not exists(select 1 from public.challenge_slots where id=p_selected_slot_id and challenge_id=p_challenge_id) then raise exception 'invalid time'; end if;
  select bool_and(accepted_at is not null) into v_all_accepted from public.challenge_participants where challenge_id=p_challenge_id;
  if v_all_accepted then
    update public.challenges set status='confirmed', selected_slot_id=coalesce(p_selected_slot_id,selected_slot_id,(select id from public.challenge_slots where challenge_id=p_challenge_id order by starts_at limit 1))
    where id=p_challenge_id returning * into v_challenge;
    insert into public.matches(challenge_id,sport,format,status,starts_at,ends_at,venue_name,rating_exempt)
    select v_challenge.id,v_challenge.sport,v_challenge.format,'confirmed',s.starts_at,s.ends_at,v_challenge.venue_name,
      (v_challenge.rating_exempt or v_challenge.sport in ('volleyball','cricket','soccer'))
    from public.challenge_slots s where s.id=v_challenge.selected_slot_id returning id into v_match_id;
    insert into public.match_participants(match_id,user_id,team)
    select v_match_id,user_id,team from public.challenge_participants where challenge_id=p_challenge_id;
  end if;
  return v_match_id;
end;
$$;

create or replace function public.mark_notifications_read(p_ids uuid[] default null)
returns integer language plpgsql security definer set search_path = '' as $$
declare v_count integer;
begin
  update public.notifications set read_at=now()
  where user_id=auth.uid() and read_at is null and (p_ids is null or id=any(p_ids));
  get diagnostics v_count = row_count; return v_count;
end;
$$;

create or replace function public.request_account_deletion()
returns void language plpgsql security definer set search_path = '' as $$
begin
  insert into public.account_deletion_requests(user_id,status,requested_at,process_after)
  values(auth.uid(),'requested',now(),now()+interval '7 days')
  on conflict(user_id) do update set status='requested',requested_at=now(),process_after=now()+interval '7 days',completed_at=null;
  update public.profiles set is_discoverable=false where id=auth.uid();
  delete from public.device_tokens where user_id=auth.uid();
end;
$$;

-- Mutations are only available through validated RPCs.
revoke insert, update, delete on public.profile_locations from authenticated;
revoke insert, update on public.connections from authenticated;
revoke insert on public.conversations, public.conversation_members, public.messages from authenticated;
revoke insert, update on public.challenges, public.challenge_participants from authenticated;
revoke insert on public.challenge_slots from authenticated;
revoke update on public.notifications from authenticated;

revoke all on function public.update_my_location(double precision,double precision,double precision) from public;
revoke all on function public.clear_my_location() from public;
revoke all on function public.find_nearby_players(public.sport_code,double precision,integer) from public;
revoke all on function public.send_connection_request(uuid) from public;
revoke all on function public.respond_connection_request(uuid,boolean) from public;
revoke all on function public.set_player_blocked(uuid,boolean) from public;
revoke all on function public.create_conversation(public.sport_code,uuid[],text) from public;
revoke all on function public.send_chat_message(uuid,public.message_kind,text,jsonb) from public;
revoke all on function public.create_challenge(public.sport_code,public.match_format,jsonb,jsonb,text,text,uuid,boolean) from public;
revoke all on function public.respond_to_challenge(uuid,boolean,uuid) from public;
revoke all on function public.mark_notifications_read(uuid[]) from public;
revoke all on function public.request_account_deletion() from public;

grant execute on function public.update_my_location(double precision,double precision,double precision) to authenticated;
grant execute on function public.clear_my_location() to authenticated;
grant execute on function public.find_nearby_players(public.sport_code,double precision,integer) to authenticated;
grant execute on function public.send_connection_request(uuid) to authenticated;
grant execute on function public.respond_connection_request(uuid,boolean) to authenticated;
grant execute on function public.set_player_blocked(uuid,boolean) to authenticated;
grant execute on function public.create_conversation(public.sport_code,uuid[],text) to authenticated;
grant execute on function public.send_chat_message(uuid,public.message_kind,text,jsonb) to authenticated;
grant execute on function public.create_challenge(public.sport_code,public.match_format,jsonb,jsonb,text,text,uuid,boolean) to authenticated;
grant execute on function public.respond_to_challenge(uuid,boolean,uuid) to authenticated;
grant execute on function public.mark_notifications_read(uuid[]) to authenticated;
grant execute on function public.request_account_deletion() to authenticated;

comment on table public.profile_locations is 'Private exact coordinates. Clients only receive computed distance from find_nearby_players.';
commit;
