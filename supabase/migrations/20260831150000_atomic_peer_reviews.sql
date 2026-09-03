-- Atomic group-sport peer review submission, including optional written feedback.
begin;

create or replace function public.submit_peer_review(
  p_match_id uuid,
  p_player_id uuid,
  p_skill_scores jsonb,
  p_written_review text default ''
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  target_match public.matches%rowtype;
  allowed_categories text[];
  score_item record;
  score_count integer := 0;
  score_total integer := 0;
  review_id uuid;
  normalized_review text := trim(coalesce(p_written_review, ''));
begin
  if caller_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if caller_id = p_player_id then
    raise exception 'Players cannot review themselves' using errcode = '22023';
  end if;
  if char_length(normalized_review) > 500 then
    raise exception 'Written reviews are limited to 500 characters' using errcode = '22023';
  end if;
  if jsonb_typeof(p_skill_scores) <> 'object' then
    raise exception 'Skill scores must be a JSON object' using errcode = '22023';
  end if;

  select * into target_match
  from public.matches
  where id = p_match_id;

  if not found or target_match.status <> 'completed' or target_match.verified_at is null then
    raise exception 'Reviews require a verified completed fixture' using errcode = '22023';
  end if;
  if target_match.sport not in ('volleyball', 'cricket', 'soccer') then
    raise exception 'Peer reviews are only available for group sports' using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.match_participants
    where match_id = p_match_id and user_id = caller_id
  ) or not exists (
    select 1 from public.match_participants
    where match_id = p_match_id and user_id = p_player_id
  ) then
    raise exception 'Both people must have participated in the fixture' using errcode = '42501';
  end if;

  allowed_categories := case target_match.sport
    when 'volleyball' then array['Serving', 'Setting', 'Defense']
    when 'cricket' then array['Batting', 'Bowling', 'Fielding']
    when 'soccer' then array['Passing', 'Finishing', 'Defense']
  end;

  for score_item in select key, value from jsonb_each_text(p_skill_scores)
  loop
    if not (score_item.key = any(allowed_categories)) then
      raise exception 'Unsupported skill category: %', score_item.key using errcode = '22023';
    end if;
    if score_item.value !~ '^[1-5]$' then
      raise exception 'Skill scores must be whole numbers from 1 to 5' using errcode = '22023';
    end if;
    score_count := score_count + 1;
    score_total := score_total + score_item.value::integer;
  end loop;

  if score_count <> cardinality(allowed_categories) then
    raise exception 'Every sport skill category must be scored once' using errcode = '22023';
  end if;

  insert into public.teammate_reviews (
    match_id, reviewer_id, player_id, sport, overall_rating, written_review
  ) values (
    p_match_id,
    caller_id,
    p_player_id,
    target_match.sport,
    round(score_total::numeric / score_count)::smallint,
    normalized_review
  ) returning id into review_id;

  for score_item in select key, value from jsonb_each_text(p_skill_scores)
  loop
    insert into public.peer_skill_ratings (
      subject_user_id, reviewer_user_id, sport, category, score, match_id
    ) values (
      p_player_id, caller_id, target_match.sport,
      score_item.key, score_item.value::smallint, p_match_id
    );
  end loop;

  insert into public.notifications (user_id, kind, payload)
  values (
    p_player_id,
    'peer_review_received',
    jsonb_build_object('matchId', p_match_id, 'sport', target_match.sport, 'reviewId', review_id)
  );

  return review_id;
end;
$$;

revoke all on function public.submit_peer_review(uuid, uuid, jsonb, text) from public;
grant execute on function public.submit_peer_review(uuid, uuid, jsonb, text) to authenticated;

-- Force all review writes through the validated transaction above.
revoke insert on public.teammate_reviews from authenticated;
revoke insert on public.peer_skill_ratings from authenticated;

comment on function public.submit_peer_review(uuid, uuid, jsonb, text) is
  'Submits category scores and optional written feedback after a verified group fixture.';

commit;
