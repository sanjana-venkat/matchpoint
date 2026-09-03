-- Match Point rating engine v2: deterministic uncertainty-aware updates.
-- Competitive ratings are sport-specific and are settled only inside one DB transaction.

begin;

create table public.rating_system_config (
  version integer primary key,
  starting_rating numeric(12,6) not null,
  initial_uncertainty numeric(8,6) not null,
  minimum_uncertainty numeric(8,6) not null,
  scale numeric(8,6) not null,
  minimum_k numeric(8,6) not null,
  maximum_k numeric(8,6) not null,
  uncertainty_decay numeric(8,6) not null,
  provisional_games integer not null,
  review_prior_rating numeric(8,6) not null,
  review_prior_count numeric(8,6) not null,
  created_at timestamptz not null default now(),
  check (initial_uncertainty >= minimum_uncertainty),
  check (maximum_k >= minimum_k),
  check (uncertainty_decay > 0 and uncertainty_decay <= 1),
  check (provisional_games >= 0)
);

alter table public.rating_system_config enable row level security;
create policy "authenticated users read rating configuration"
on public.rating_system_config for select to authenticated using (true);

insert into public.rating_system_config (
  version, starting_rating, initial_uncertainty, minimum_uncertainty, scale,
  minimum_k, maximum_k, uncertainty_decay, provisional_games,
  review_prior_rating, review_prior_count
) values (2, 80, 12, 3, 10, 2, 12, 0.96, 10, 4, 5);

alter table public.sport_profiles
  alter column rating type numeric(12,6) using rating::numeric,
  alter column rating set default 80,
  add column uncertainty numeric(8,6) not null default 12
    check (uncertainty between 3 and 12),
  add column wins integer not null default 0 check (wins >= 0),
  add column losses integer not null default 0 check (losses >= 0),
  add column draws integer not null default 0 check (draws >= 0);

alter table public.match_participants
  alter column rating_before type numeric(12,6) using rating_before::numeric,
  alter column rating_after type numeric(12,6) using rating_after::numeric,
  add column uncertainty_before numeric(8,6),
  add column uncertainty_after numeric(8,6),
  add column rating_delta numeric(12,6),
  drop constraint match_participants_result_reported_team_check,
  add constraint match_participants_result_reported_team_check
    check (result_reported_team in (0, 1, 2));

alter table public.rating_events
  alter column rating_before type numeric(12,6) using rating_before::numeric,
  alter column rating_after type numeric(12,6) using rating_after::numeric,
  add column uncertainty_before numeric(8,6) not null default 12,
  add column uncertainty_after numeric(8,6) not null default 12,
  add column rating_delta numeric(12,6) not null default 0;

create or replace function public.rating_expected_score(
  rating_a numeric,
  rating_b numeric,
  rating_scale numeric default 10
)
returns numeric
language sql
immutable
strict
set search_path = ''
as $$
  select 1.0 / (1.0 + exp(-((rating_a - rating_b) / rating_scale)::double precision));
$$;

create or replace function public.rating_k_factor(
  player_uncertainty numeric,
  minimum_uncertainty numeric default 3,
  initial_uncertainty numeric default 12,
  minimum_k numeric default 2,
  maximum_k numeric default 12
)
returns numeric
language sql
immutable
strict
set search_path = ''
as $$
  select minimum_k +
    least(1.0, greatest(0.0,
      (player_uncertainty - minimum_uncertainty) /
      nullif(initial_uncertainty - minimum_uncertainty, 0)
    )) * (maximum_k - minimum_k);
$$;

create or replace function public.rating_new_uncertainty(
  old_uncertainty numeric,
  minimum_uncertainty numeric default 3,
  uncertainty_decay numeric default 0.96
)
returns numeric
language sql
immutable
strict
set search_path = ''
as $$
  select greatest(minimum_uncertainty, old_uncertainty * uncertainty_decay);
$$;

create or replace function public.rating_team_average(ratings numeric[])
returns numeric
language sql
immutable
strict
set search_path = ''
as $$
  select case when cardinality(ratings) = 0 then null
    else (select avg(value) from unnest(ratings) as value)
  end;
$$;

create or replace function public.bayesian_review_rating(
  review_count bigint,
  actual_average numeric,
  prior_rating numeric default 4,
  prior_review_count numeric default 5
)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select (prior_review_count * prior_rating + greatest(review_count, 0) * coalesce(actual_average, prior_rating))
    / (prior_review_count + greatest(review_count, 0));
$$;

revoke all on function public.rating_expected_score(numeric, numeric, numeric) from public;
revoke all on function public.rating_k_factor(numeric, numeric, numeric, numeric, numeric) from public;
revoke all on function public.rating_new_uncertainty(numeric, numeric, numeric) from public;
revoke all on function public.rating_team_average(numeric[]) from public;
revoke all on function public.bayesian_review_rating(bigint, numeric, numeric, numeric) from public;

create table public.teammate_reviews (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  reviewer_id uuid not null references public.profiles(id) on delete cascade,
  player_id uuid not null references public.profiles(id) on delete cascade,
  sport public.sport_code not null,
  overall_rating smallint not null check (overall_rating between 1 and 5),
  teamwork smallint check (teamwork between 1 and 5),
  communication smallint check (communication between 1 and 5),
  effort smallint check (effort between 1 and 5),
  sportsmanship smallint check (sportsmanship between 1 and 5),
  written_review text not null default '' check (char_length(written_review) <= 1000),
  created_at timestamptz not null default now(),
  check (reviewer_id <> player_id),
  unique (match_id, reviewer_id, player_id)
);
create index teammate_reviews_player_sport_index
  on public.teammate_reviews (player_id, sport, created_at desc);

alter table public.teammate_reviews enable row level security;

create policy "participants view reviews involving themselves"
on public.teammate_reviews for select to authenticated
using (reviewer_id = (select auth.uid()) or player_id = (select auth.uid()));

create policy "verified participants submit one review per player"
on public.teammate_reviews for insert to authenticated
with check (
  reviewer_id = (select auth.uid())
  and reviewer_id <> player_id
  and exists (
    select 1
    from public.matches m
    where m.id = teammate_reviews.match_id
      and m.sport = teammate_reviews.sport
      and m.status = 'completed'
      and m.verified_at is not null
  )
  and exists (
    select 1 from public.match_participants reviewer
    where reviewer.match_id = teammate_reviews.match_id and reviewer.user_id = (select auth.uid())
  )
  and exists (
    select 1 from public.match_participants subject
    where subject.match_id = teammate_reviews.match_id and subject.user_id = teammate_reviews.player_id
  )
);

-- The existing category-level scores use the same verified-match boundary.
alter table public.peer_skill_ratings
  add constraint peer_skill_ratings_match_fk
  foreign key (match_id) references public.matches(id) on delete cascade;

drop policy "users submit peer ratings" on public.peer_skill_ratings;
create policy "verified participants submit peer skill ratings"
on public.peer_skill_ratings for insert to authenticated
with check (
  reviewer_user_id = (select auth.uid())
  and reviewer_user_id <> subject_user_id
  and match_id is not null
  and sport in ('volleyball', 'cricket', 'soccer')
  and exists (
    select 1
    from public.matches m
    where m.id = peer_skill_ratings.match_id
      and m.sport = peer_skill_ratings.sport
      and m.status = 'completed'
      and m.verified_at is not null
  )
  and exists (
    select 1 from public.match_participants reviewer
    where reviewer.match_id = peer_skill_ratings.match_id and reviewer.user_id = (select auth.uid())
  )
  and exists (
    select 1 from public.match_participants subject
    where subject.match_id = peer_skill_ratings.match_id
      and subject.user_id = peer_skill_ratings.subject_user_id
  )
);

create or replace function public.get_teammate_review_summary(
  p_user_id uuid,
  p_sport public.sport_code
)
returns table(review_count bigint, actual_average numeric, display_rating numeric)
language sql
stable
security definer
set search_path = ''
as $$
  with aggregate as (
    select count(*) as review_count, avg(overall_rating::numeric) as actual_average
    from public.teammate_reviews
    where player_id = p_user_id and sport = p_sport
  )
  select
    aggregate.review_count,
    aggregate.actual_average,
    public.bayesian_review_rating(
      aggregate.review_count,
      aggregate.actual_average,
      config.review_prior_rating,
      config.review_prior_count
    )
  from aggregate
  cross join public.rating_system_config config
  where config.version = 2;
$$;

revoke all on function public.get_teammate_review_summary(uuid, public.sport_code) from public;
grant execute on function public.get_teammate_review_summary(uuid, public.sport_code) to authenticated;

create or replace function public.report_match_result(
  p_match_id uuid,
  p_result_team smallint
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  target_match public.matches%rowtype;
  config public.rating_system_config%rowtype;
  report_count integer;
  reported_count integer;
  distinct_results integer;
  settled_result smallint;
  team_one_rating numeric;
  team_two_rating numeric;
  expected_team_one numeric;
  participant record;
  player_expected numeric;
  player_actual numeric;
  player_k numeric;
  player_delta numeric;
  player_rating_after numeric;
  player_uncertainty_after numeric;
begin
  if caller_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if p_result_team is null or p_result_team not in (0, 1, 2) then
    raise exception 'Result must be 0 (draw), 1, or 2' using errcode = '22023';
  end if;

  select * into target_match
  from public.matches
  where id = p_match_id
  for update;

  if not found then raise exception 'Match not found' using errcode = 'P0002'; end if;
  if target_match.status = 'completed' then
    return jsonb_build_object('status', 'completed', 'settled', true);
  end if;
  if target_match.status not in ('confirmed', 'awaitingResult', 'resultDisputed') then
    raise exception 'Match is not ready for a result' using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.match_participants
    where match_id = p_match_id and user_id = caller_id
  ) then
    raise exception 'Only a participant can report this result' using errcode = '42501';
  end if;

  update public.match_participants
  set result_reported_team = p_result_team, reported_at = now(), confirmed_at = now()
  where match_id = p_match_id and user_id = caller_id;

  select count(*), count(result_reported_team), count(distinct result_reported_team)
  into report_count, reported_count, distinct_results
  from public.match_participants
  where match_id = p_match_id;

  if report_count <> reported_count then
    update public.matches set status = 'awaitingResult' where id = p_match_id;
    return jsonb_build_object('status', 'awaitingResult', 'settled', false);
  end if;

  if distinct_results <> 1 then
    update public.matches set status = 'resultDisputed' where id = p_match_id;
    return jsonb_build_object('status', 'resultDisputed', 'settled', false);
  end if;

  select min(result_reported_team) into settled_result
  from public.match_participants where match_id = p_match_id;

  -- Rating-exempt matches complete without touching competitive state.
  if target_match.rating_exempt then
    update public.matches
    set status = 'completed', verified_at = now(), rating_algorithm_version = 2
    where id = p_match_id;
    return jsonb_build_object('status', 'completed', 'settled', true, 'ratingExempt', true);
  end if;

  -- Group sports intentionally use fixtures and teammate reviews only.
  if target_match.sport in ('volleyball', 'cricket', 'soccer') then
    update public.matches
    set status = 'completed', verified_at = now(), rating_algorithm_version = 2
    where id = p_match_id;
    return jsonb_build_object(
      'status', 'completed',
      'settled', true,
      'ratingExempt', true,
      'competitiveRating', false
    );
  end if;

  select * into config from public.rating_system_config where version = 2;
  if not found then raise exception 'Rating configuration v2 is missing'; end if;

  if not exists (select 1 from public.match_participants where match_id = p_match_id and team = 1)
     or not exists (select 1 from public.match_participants where match_id = p_match_id and team = 2) then
    raise exception 'Both teams require at least one participant' using errcode = '22023';
  end if;

  -- Lock every affected sport row in a deterministic order before snapshotting.
  perform 1
  from public.sport_profiles sp
  join public.match_participants mp on mp.user_id = sp.user_id
  where mp.match_id = p_match_id and sp.sport = target_match.sport
  order by sp.user_id
  for update of sp;

  if (select count(*) from public.match_participants where match_id = p_match_id) <>
     (select count(*)
      from public.match_participants mp
      join public.sport_profiles sp on sp.user_id = mp.user_id and sp.sport = target_match.sport
      where mp.match_id = p_match_id and sp.is_active and not sp.rating_opt_out) then
    raise exception 'Every participant needs an active rated profile for this sport' using errcode = '22023';
  end if;

  update public.match_participants mp
  set rating_before = sp.rating,
      uncertainty_before = sp.uncertainty
  from public.sport_profiles sp
  where mp.match_id = p_match_id
    and sp.user_id = mp.user_id
    and sp.sport = target_match.sport;

  select avg(rating_before) filter (where team = 1),
         avg(rating_before) filter (where team = 2)
  into team_one_rating, team_two_rating
  from public.match_participants
  where match_id = p_match_id;

  expected_team_one := public.rating_expected_score(team_one_rating, team_two_rating, config.scale);

  for participant in
    select mp.user_id, mp.team, mp.rating_before, mp.uncertainty_before
    from public.match_participants mp
    where mp.match_id = p_match_id
    order by mp.user_id
  loop
    player_expected := case when participant.team = 1 then expected_team_one else 1 - expected_team_one end;
    player_actual := case
      when settled_result = 0 then 0.5
      when settled_result = participant.team then 1.0
      else 0.0
    end;
    player_k := public.rating_k_factor(
      participant.uncertainty_before,
      config.minimum_uncertainty,
      config.initial_uncertainty,
      config.minimum_k,
      config.maximum_k
    );
    player_delta := player_k * (player_actual - player_expected);
    player_rating_after := greatest(0, participant.rating_before + player_delta);
    player_uncertainty_after := public.rating_new_uncertainty(
      participant.uncertainty_before,
      config.minimum_uncertainty,
      config.uncertainty_decay
    );

    update public.sport_profiles
    set rating = player_rating_after,
        uncertainty = player_uncertainty_after,
        matches_played = matches_played + 1,
        wins = wins + case when player_actual = 1 then 1 else 0 end,
        losses = losses + case when player_actual = 0 then 1 else 0 end,
        draws = draws + case when player_actual = 0.5 then 1 else 0 end,
        rating_version = 2
    where user_id = participant.user_id and sport = target_match.sport;

    update public.match_participants
    set rating_after = player_rating_after,
        uncertainty_after = player_uncertainty_after,
        rating_delta = player_delta
    where match_id = p_match_id and user_id = participant.user_id;

    insert into public.rating_events (
      match_id, user_id, sport, rating_before, rating_after,
      uncertainty_before, uncertainty_after, rating_delta,
      expected_score, actual_score, algorithm_version, inputs
    ) values (
      p_match_id, participant.user_id, target_match.sport,
      participant.rating_before, player_rating_after,
      participant.uncertainty_before, player_uncertainty_after, player_delta,
      player_expected, player_actual, 2,
      jsonb_build_object(
        'teamOneRating', team_one_rating,
        'teamTwoRating', team_two_rating,
        'kFactor', player_k,
        'scale', config.scale,
        'uncertaintyDecay', config.uncertainty_decay
      )
    );

    insert into public.notifications (user_id, kind, payload)
    values (
      participant.user_id,
      'rating_updated',
      jsonb_build_object('matchId', p_match_id, 'sport', target_match.sport, 'delta', player_delta)
    );
  end loop;

  update public.matches
  set status = 'completed', verified_at = now(), rating_algorithm_version = 2
  where id = p_match_id;

  return jsonb_build_object(
    'status', 'completed',
    'settled', true,
    'ratingExempt', false,
    'resultTeam', settled_result
  );
end;
$$;

revoke all on function public.report_match_result(uuid, smallint) from public;
grant execute on function public.report_match_result(uuid, smallint) to authenticated;

-- Clients may edit sport preferences, but never competitive state.
revoke insert, update on public.sport_profiles from authenticated;
grant update (
  rating_opt_out, partner_status, home_court, owns_equipment,
  played_tournaments, self_assessment, social_skill_label, is_active
) on public.sport_profiles to authenticated;

-- Result reports and rating snapshots must go through the transactional RPC.
revoke update on public.match_participants from authenticated;
revoke insert, update, delete on public.rating_events from authenticated;

grant select on public.rating_system_config to authenticated;
grant select, insert on public.teammate_reviews to authenticated;

comment on function public.report_match_result(uuid, smallint) is
  'Records one participant result and atomically settles rating v2 after unanimous confirmation. Result team 0 means draw.';

commit;
