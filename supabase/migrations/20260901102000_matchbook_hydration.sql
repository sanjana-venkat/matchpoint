-- Caller-scoped read model for challenges, schedule, verification, and history.
begin;

create or replace function public.my_matchbook()
returns table (
  challenge_id uuid, match_id uuid, sport public.sport_code, format text, status text,
  note text, venue text, rating_exempt boolean, proposed_by_me boolean,
  starts_at timestamptz, proposed_starts timestamptz[], participant_ids uuid[],
  participant_names text[], participant_avatar_ids text[], my_team smallint,
  my_reported_team smallint, other_reported_team smallint, rating_before integer,
  rating_after integer, opponent_rating integer, scores jsonb
) language sql stable security definer set search_path = '' as $$
  with challenge_rows as (
    select c.id as challenge_id, m.id as match_id, c.sport, c.format::text,
      coalesce(m.status, c.status)::text as status, c.note, coalesce(m.venue_name, c.venue_name, '') as venue,
      coalesce(m.rating_exempt, c.rating_exempt, false) as rating_exempt,
      c.created_by = auth.uid() as proposed_by_me,
      coalesce(m.starts_at, selected.starts_at, first_slot.starts_at, c.created_at) as starts_at,
      coalesce((select array_agg(cs.starts_at order by cs.starts_at) from public.challenge_slots cs where cs.challenge_id = c.id), array[]::timestamptz[]) proposed_starts,
      coalesce((select array_agg(p.id order by p.display_name) from public.challenge_participants cp2
        join public.profiles p on p.id = cp2.user_id where cp2.challenge_id = c.id and cp2.user_id <> auth.uid()), array[]::uuid[]) participant_ids,
      coalesce((select array_agg(p.display_name order by p.display_name) from public.challenge_participants cp2
        join public.profiles p on p.id = cp2.user_id where cp2.challenge_id = c.id and cp2.user_id <> auth.uid()), array[]::text[]) participant_names,
      coalesce((select array_agg(coalesce(p.avatar_id, '') order by p.display_name) from public.challenge_participants cp2
        join public.profiles p on p.id = cp2.user_id where cp2.challenge_id = c.id and cp2.user_id <> auth.uid()), array[]::text[]) participant_avatar_ids,
      coalesce(mine.team, cp.team) my_team, mine.result_reported_team my_reported_team,
      (select mp.result_reported_team from public.match_participants mp where mp.match_id = m.id and mp.user_id <> auth.uid() and mp.result_reported_team is not null limit 1) other_reported_team,
      mine.rating_before, mine.rating_after,
      (select round(avg(mp.rating_before))::integer from public.match_participants mp where mp.match_id = m.id and mp.user_id <> auth.uid()) opponent_rating,
      coalesce((select jsonb_agg(jsonb_build_object('id', gs.id, 'game_number', gs.game_number,
        'team_one_score', gs.team_one_score, 'team_two_score', gs.team_two_score) order by gs.game_number)
        from public.game_scores gs where gs.match_id = m.id), '[]'::jsonb) scores
    from public.challenge_participants cp
    join public.challenges c on c.id = cp.challenge_id
    left join public.challenge_slots selected on selected.id = c.selected_slot_id
    left join lateral (select starts_at from public.challenge_slots where challenge_id = c.id order by starts_at limit 1) first_slot on true
    left join public.matches m on m.challenge_id = c.id
    left join public.match_participants mine on mine.match_id = m.id and mine.user_id = auth.uid()
    where cp.user_id = auth.uid()
  ), standalone_matches as (
    select null::uuid challenge_id, m.id match_id, m.sport, m.format::text, m.status::text,
      ''::text note, coalesce(m.venue_name, '') venue, m.rating_exempt, true proposed_by_me,
      m.starts_at, array[m.starts_at]::timestamptz[] proposed_starts,
      coalesce((select array_agg(p.id order by p.display_name) from public.match_participants mp2
        join public.profiles p on p.id = mp2.user_id where mp2.match_id = m.id and mp2.user_id <> auth.uid()), array[]::uuid[]) participant_ids,
      coalesce((select array_agg(p.display_name order by p.display_name) from public.match_participants mp2
        join public.profiles p on p.id = mp2.user_id where mp2.match_id = m.id and mp2.user_id <> auth.uid()), array[]::text[]) participant_names,
      coalesce((select array_agg(coalesce(p.avatar_id, '') order by p.display_name) from public.match_participants mp2
        join public.profiles p on p.id = mp2.user_id where mp2.match_id = m.id and mp2.user_id <> auth.uid()), array[]::text[]) participant_avatar_ids,
      mine.team my_team, mine.result_reported_team my_reported_team,
      (select mp.result_reported_team from public.match_participants mp where mp.match_id = m.id and mp.user_id <> auth.uid() and mp.result_reported_team is not null limit 1) other_reported_team,
      mine.rating_before, mine.rating_after,
      (select round(avg(mp.rating_before))::integer from public.match_participants mp where mp.match_id = m.id and mp.user_id <> auth.uid()) opponent_rating,
      coalesce((select jsonb_agg(jsonb_build_object('id', gs.id, 'game_number', gs.game_number,
        'team_one_score', gs.team_one_score, 'team_two_score', gs.team_two_score) order by gs.game_number)
        from public.game_scores gs where gs.match_id = m.id), '[]'::jsonb) scores
    from public.matches m join public.match_participants mine on mine.match_id = m.id and mine.user_id = auth.uid()
    where m.challenge_id is null
  )
  select * from challenge_rows union all select * from standalone_matches
  order by starts_at desc;
$$;

revoke all on function public.my_matchbook() from public;
grant execute on function public.my_matchbook() to authenticated;

commit;
