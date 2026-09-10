-- Closed-beta integrity checks for sport-aware challenges, score uploads, and chat.
-- Keep client mistakes or crafted API calls from creating impossible records.
begin;

create or replace function public.users_are_connected(p_user_a uuid, p_user_b uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.connections c
    where c.status = 'accepted'
      and ((c.requester_id = p_user_a and c.recipient_id = p_user_b)
        or (c.requester_id = p_user_b and c.recipient_id = p_user_a))
  );
$$;

revoke all on function public.users_are_connected(uuid, uuid) from public, anon, authenticated;

alter function public.send_chat_message(uuid, public.message_kind, text, jsonb)
  rename to send_chat_message_unchecked;
revoke all on function public.send_chat_message_unchecked(uuid, public.message_kind, text, jsonb)
  from public, anon, authenticated;

create function public.send_chat_message(
  p_conversation_id uuid,
  p_kind public.message_kind,
  p_body text default null,
  p_payload jsonb default '{}'::jsonb
) returns uuid language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'authentication required' using errcode = '42501'; end if;
  if not exists (
    select 1 from public.conversation_members cm
    where cm.conversation_id = p_conversation_id
      and cm.user_id = auth.uid()
      and cm.accepted_at is not null
  ) then
    raise exception 'accept this conversation before replying' using errcode = '42501';
  end if;
  if exists (
    select 1
    from public.conversation_members cm
    join public.blocks b on
      (b.blocker_id = auth.uid() and b.blocked_id = cm.user_id)
      or (b.blocker_id = cm.user_id and b.blocked_id = auth.uid())
    where cm.conversation_id = p_conversation_id and cm.user_id <> auth.uid()
  ) then
    raise exception 'conversation unavailable' using errcode = '42501';
  end if;
  return public.send_chat_message_unchecked(p_conversation_id, p_kind, p_body, p_payload);
end;
$$;

revoke all on function public.send_chat_message(uuid, public.message_kind, text, jsonb) from public, anon;
grant execute on function public.send_chat_message(uuid, public.message_kind, text, jsonb) to authenticated;

alter function public.create_challenge(
  public.sport_code, public.match_format, jsonb, jsonb, text, text, uuid, boolean
) rename to create_challenge_unchecked;
revoke all on function public.create_challenge_unchecked(
  public.sport_code, public.match_format, jsonb, jsonb, text, text, uuid, boolean
) from public, anon, authenticated;

create function public.create_challenge(
  p_sport public.sport_code,
  p_format public.match_format,
  p_participants jsonb,
  p_slots jsonb,
  p_note text default '',
  p_venue_name text default null,
  p_conversation_id uuid default null,
  p_rating_exempt boolean default false
) returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_item jsonb;
  v_user_id uuid;
  v_start timestamptz;
  v_end timestamptz;
  v_expected integer;
  v_team_one integer;
  v_team_two integer;
begin
  if auth.uid() is null then raise exception 'authentication required' using errcode = '42501'; end if;
  if p_sport not in ('pickleball', 'badminton') then raise exception 'sport is coming soon'; end if;
  if p_format not in ('singles', 'doubles') then raise exception 'invalid beta format'; end if;
  if not exists (
    select 1 from public.sport_profiles sp
    where sp.user_id = auth.uid() and sp.sport = p_sport and sp.is_active
  ) then raise exception 'activate this sport before creating a challenge'; end if;

  if jsonb_typeof(p_participants) <> 'array' then raise exception 'participants required'; end if;
  v_expected := case when p_format = 'singles' then 1 else 3 end;
  if jsonb_array_length(p_participants) <> v_expected then raise exception 'invalid participant count'; end if;
  if (select count(distinct value->>'user_id') from jsonb_array_elements(p_participants)) <> v_expected then
    raise exception 'participants must be unique';
  end if;

  for v_item in select value from jsonb_array_elements(p_participants) loop
    v_user_id := (v_item->>'user_id')::uuid;
    if v_user_id = auth.uid() or not exists (
      select 1 from public.sport_profiles sp
      where sp.user_id = v_user_id and sp.sport = p_sport and sp.is_active
    ) then raise exception 'every participant must play the selected sport'; end if;
    if not public.users_are_connected(auth.uid(), v_user_id) then
      raise exception 'challenges can only be sent to connections';
    end if;
    if p_conversation_id is not null and not exists (
      select 1 from public.conversation_members cm
      where cm.conversation_id = p_conversation_id and cm.user_id = v_user_id
    ) then raise exception 'challenge participant is not in this conversation'; end if;
  end loop;

  if p_conversation_id is not null and not exists (
    select 1 from public.conversation_members cm
    where cm.conversation_id = p_conversation_id and cm.user_id = auth.uid() and cm.accepted_at is not null
  ) then raise exception 'conversation unavailable'; end if;

  select 1 + count(*) filter (where (value->>'team')::smallint = 1),
         count(*) filter (where (value->>'team')::smallint = 2)
  into v_team_one, v_team_two
  from jsonb_array_elements(p_participants);
  if (p_format = 'singles' and (v_team_one <> 1 or v_team_two <> 1))
     or (p_format = 'doubles' and (v_team_one <> 2 or v_team_two <> 2)) then
    raise exception 'invalid team assignment';
  end if;

  if jsonb_typeof(p_slots) <> 'array' or jsonb_array_length(p_slots) not between 1 and 3 then
    raise exception 'one to three times required';
  end if;
  for v_item in select value from jsonb_array_elements(p_slots) loop
    v_start := (v_item->>'starts_at')::timestamptz;
    v_end := (v_item->>'ends_at')::timestamptz;
    if v_start < now() - interval '5 minutes' or v_end <= v_start or v_end > v_start + interval '8 hours' then
      raise exception 'invalid challenge time';
    end if;
  end loop;

  return public.create_challenge_unchecked(
    p_sport, p_format, p_participants, p_slots, p_note, p_venue_name,
    p_conversation_id, p_rating_exempt
  );
end;
$$;

revoke all on function public.create_challenge(
  public.sport_code, public.match_format, jsonb, jsonb, text, text, uuid, boolean
) from public, anon;
grant execute on function public.create_challenge(
  public.sport_code, public.match_format, jsonb, jsonb, text, text, uuid, boolean
) to authenticated;

alter function public.create_uploaded_match(public.sport_code, public.match_format, jsonb, timestamptz, boolean)
  rename to create_uploaded_match_unchecked;
revoke all on function public.create_uploaded_match_unchecked(
  public.sport_code, public.match_format, jsonb, timestamptz, boolean
) from public, anon, authenticated;

create function public.create_uploaded_match(
  p_sport public.sport_code,
  p_format public.match_format,
  p_participants jsonb,
  p_starts_at timestamptz default now(),
  p_rating_exempt boolean default false
) returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_item jsonb;
  v_user_id uuid;
  v_expected integer;
  v_team_one integer;
  v_team_two integer;
begin
  if auth.uid() is null then raise exception 'authentication required' using errcode = '42501'; end if;
  if p_sport not in ('pickleball', 'badminton') then raise exception 'sport is coming soon'; end if;
  if p_format not in ('singles', 'doubles') then raise exception 'invalid beta format'; end if;
  if p_starts_at > now() + interval '15 minutes' then raise exception 'uploaded matches cannot be in the future'; end if;
  if not exists (
    select 1 from public.sport_profiles sp
    where sp.user_id = auth.uid() and sp.sport = p_sport and sp.is_active
  ) then raise exception 'activate this sport before uploading a match'; end if;

  if jsonb_typeof(p_participants) <> 'array' then raise exception 'participants required'; end if;
  v_expected := case when p_format = 'singles' then 1 else 3 end;
  if jsonb_array_length(p_participants) <> v_expected then raise exception 'invalid participant count'; end if;
  if (select count(distinct value->>'user_id') from jsonb_array_elements(p_participants)) <> v_expected then
    raise exception 'participants must be unique';
  end if;
  for v_item in select value from jsonb_array_elements(p_participants) loop
    v_user_id := (v_item->>'user_id')::uuid;
    if v_user_id = auth.uid() or not exists (
      select 1 from public.sport_profiles sp
      where sp.user_id = v_user_id and sp.sport = p_sport and sp.is_active
    ) then raise exception 'every participant must play the selected sport'; end if;
    if not public.users_are_connected(auth.uid(), v_user_id) then
      raise exception 'scores can only be uploaded with connections';
    end if;
  end loop;

  select 1 + count(*) filter (where (value->>'team')::smallint = 1),
         count(*) filter (where (value->>'team')::smallint = 2)
  into v_team_one, v_team_two
  from jsonb_array_elements(p_participants);
  if (p_format = 'singles' and (v_team_one <> 1 or v_team_two <> 1))
     or (p_format = 'doubles' and (v_team_one <> 2 or v_team_two <> 2)) then
    raise exception 'invalid team assignment';
  end if;

  return public.create_uploaded_match_unchecked(
    p_sport, p_format, p_participants, p_starts_at, p_rating_exempt
  );
end;
$$;

revoke all on function public.create_uploaded_match(
  public.sport_code, public.match_format, jsonb, timestamptz, boolean
) from public, anon;
grant execute on function public.create_uploaded_match(
  public.sport_code, public.match_format, jsonb, timestamptz, boolean
) to authenticated;

alter function public.save_and_report_match_result(uuid, smallint, jsonb)
  rename to save_and_report_match_result_unchecked;
revoke all on function public.save_and_report_match_result_unchecked(uuid, smallint, jsonb)
  from public, anon, authenticated;

create function public.save_and_report_match_result(
  p_match_id uuid,
  p_result_team smallint,
  p_scores jsonb default '[]'::jsonb
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_item jsonb;
  v_one smallint;
  v_two smallint;
  v_team_one_wins integer := 0;
  v_team_two_wins integer := 0;
begin
  if auth.uid() is null then raise exception 'authentication required' using errcode = '42501'; end if;
  if p_result_team not in (1, 2) then raise exception 'a winning team is required'; end if;
  if not exists (
    select 1 from public.matches m
    join public.match_participants mp on mp.match_id = m.id
    where m.id = p_match_id and mp.user_id = auth.uid()
      and m.sport in ('pickleball', 'badminton')
      and m.starts_at <= now() + interval '15 minutes'
  ) then raise exception 'match is unavailable or has not started'; end if;
  if jsonb_typeof(p_scores) <> 'array' or jsonb_array_length(p_scores) > 15 then
    raise exception 'invalid scores';
  end if;
  for v_item in select value from jsonb_array_elements(p_scores) loop
    v_one := (v_item->>'team_one_score')::smallint;
    v_two := (v_item->>'team_two_score')::smallint;
    if v_one < 0 or v_two < 0 or v_one = v_two then raise exception 'invalid game score'; end if;
    if v_one > v_two then v_team_one_wins := v_team_one_wins + 1;
    else v_team_two_wins := v_team_two_wins + 1;
    end if;
  end loop;
  if jsonb_array_length(p_scores) > 0 and (
    (v_team_one_wins > v_team_two_wins and p_result_team <> 1)
    or (v_team_two_wins > v_team_one_wins and p_result_team <> 2)
    or v_team_one_wins = v_team_two_wins
  ) then raise exception 'winner does not match the submitted scores'; end if;

  return public.save_and_report_match_result_unchecked(p_match_id, p_result_team, p_scores);
end;
$$;

revoke all on function public.save_and_report_match_result(uuid, smallint, jsonb) from public, anon;
grant execute on function public.save_and_report_match_result(uuid, smallint, jsonb) to authenticated;

comment on function public.create_challenge(
  public.sport_code, public.match_format, jsonb, jsonb, text, text, uuid, boolean
) is 'Creates a beta challenge only between connected players who share the selected active sport.';

commit;
