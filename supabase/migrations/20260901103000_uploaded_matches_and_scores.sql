-- Persist manually uploaded sessions and their game-by-game scores.
begin;

create or replace function public.create_uploaded_match(
  p_sport public.sport_code,
  p_format public.match_format,
  p_participants jsonb,
  p_starts_at timestamptz default now(),
  p_rating_exempt boolean default false
) returns uuid language plpgsql security definer set search_path = '' as $$
declare v_match_id uuid; v_item jsonb; v_user_id uuid; v_team smallint; v_count integer;
begin
  if p_sport not in ('pickleball', 'badminton') then raise exception 'sport is coming soon'; end if;
  if p_format not in ('singles', 'doubles') then raise exception 'invalid beta format'; end if;
  if jsonb_typeof(p_participants) <> 'array' then raise exception 'participants required'; end if;
  v_count := jsonb_array_length(p_participants);
  if (p_format = 'singles' and v_count <> 1) or (p_format = 'doubles' and v_count <> 3) then
    raise exception 'invalid participant count';
  end if;
  insert into public.matches(sport, format, status, starts_at, rating_exempt)
  values (p_sport, p_format, 'confirmed', coalesce(p_starts_at, now()), p_rating_exempt)
  returning id into v_match_id;
  insert into public.match_participants(match_id, user_id, team)
  values (v_match_id, auth.uid(), 1);
  for v_item in select value from jsonb_array_elements(p_participants) loop
    v_user_id := (v_item->>'user_id')::uuid;
    v_team := (v_item->>'team')::smallint;
    if v_user_id = auth.uid() or v_team not in (1, 2) or not exists (
      select 1 from public.profiles where id = v_user_id
    ) then raise exception 'invalid participant'; end if;
    insert into public.match_participants(match_id, user_id, team) values (v_match_id, v_user_id, v_team);
  end loop;
  if not exists (select 1 from public.match_participants where match_id = v_match_id and team = 2) then
    raise exception 'an opposing team is required';
  end if;
  return v_match_id;
end;
$$;

create or replace function public.save_and_report_match_result(
  p_match_id uuid,
  p_result_team smallint,
  p_scores jsonb default '[]'::jsonb
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_item jsonb; v_number smallint := 0; v_one smallint; v_two smallint;
begin
  if not exists (select 1 from public.match_participants where match_id = p_match_id and user_id = auth.uid()) then
    raise exception 'only a participant can report this result';
  end if;
  if jsonb_typeof(p_scores) <> 'array' or jsonb_array_length(p_scores) > 15 then raise exception 'invalid scores'; end if;
  if jsonb_array_length(p_scores) > 0 then
    if exists (select 1 from public.game_scores where match_id = p_match_id) then
      if (select count(*) from public.game_scores where match_id = p_match_id) <> jsonb_array_length(p_scores) then
        raise exception 'submitted scores do not match the first report';
      end if;
      for v_item in select value from jsonb_array_elements(p_scores) loop
        v_number := v_number + 1;
        v_one := (v_item->>'team_one_score')::smallint;
        v_two := (v_item->>'team_two_score')::smallint;
        if not exists (select 1 from public.game_scores where match_id = p_match_id and game_number = v_number
          and team_one_score = v_one and team_two_score = v_two) then
          raise exception 'submitted scores do not match the first report';
        end if;
      end loop;
    else
      for v_item in select value from jsonb_array_elements(p_scores) loop
        v_number := v_number + 1;
        v_one := (v_item->>'team_one_score')::smallint;
        v_two := (v_item->>'team_two_score')::smallint;
        if v_one < 0 or v_two < 0 or v_one = v_two then raise exception 'invalid game score'; end if;
        insert into public.game_scores(match_id, game_number, team_one_score, team_two_score)
        values (p_match_id, v_number, v_one, v_two);
      end loop;
    end if;
  end if;
  return public.report_match_result(p_match_id, p_result_team);
end;
$$;

revoke all on function public.create_uploaded_match(public.sport_code, public.match_format, jsonb, timestamptz, boolean) from public;
revoke all on function public.save_and_report_match_result(uuid, smallint, jsonb) from public;
grant execute on function public.create_uploaded_match(public.sport_code, public.match_format, jsonb, timestamptz, boolean) to authenticated;
grant execute on function public.save_and_report_match_result(uuid, smallint, jsonb) to authenticated;

commit;
