-- Run after all migrations against a disposable local database.
-- The transaction is rolled back so the test never leaves fixture accounts behind.
begin;

insert into auth.users (id, raw_user_meta_data) values
  ('a0000000-0000-0000-0000-000000000001', '{"username":"beta_alex","display_name":"Alex"}'::jsonb),
  ('b0000000-0000-0000-0000-000000000002', '{"username":"beta_maya","display_name":"Maya"}'::jsonb),
  ('c0000000-0000-0000-0000-000000000003', '{"username":"beta_diego","display_name":"Diego"}'::jsonb),
  ('d0000000-0000-0000-0000-000000000004', '{"username":"beta_priya","display_name":"Priya"}'::jsonb);

-- The auth trigger creates profiles in Supabase. Update those rows with explicit
-- deterministic fixture values instead of creating duplicate profiles.
insert into public.profiles (id, username, display_name, onboarding_completed_at) values
  ('a0000000-0000-0000-0000-000000000001', 'beta_alex', 'Alex', now()),
  ('b0000000-0000-0000-0000-000000000002', 'beta_maya', 'Maya', now()),
  ('c0000000-0000-0000-0000-000000000003', 'beta_diego', 'Diego', now()),
  ('d0000000-0000-0000-0000-000000000004', 'beta_priya', 'Priya', now())
on conflict (id) do update set
  username = excluded.username,
  display_name = excluded.display_name,
  onboarding_completed_at = excluded.onboarding_completed_at;

insert into public.sport_profiles (user_id, sport, is_active) values
  ('a0000000-0000-0000-0000-000000000001', 'pickleball', true),
  ('a0000000-0000-0000-0000-000000000001', 'badminton', true),
  ('b0000000-0000-0000-0000-000000000002', 'pickleball', true),
  ('c0000000-0000-0000-0000-000000000003', 'pickleball', true),
  ('d0000000-0000-0000-0000-000000000004', 'pickleball', true);

insert into public.connections (requester_id, recipient_id, status, responded_at) values
  ('a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000002', 'accepted', now()),
  ('a0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000003', 'accepted', now()),
  ('a0000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000004', 'accepted', now());

create temporary table beta_test_ids (name text primary key, id uuid not null);
grant all on beta_test_ids to authenticated;

set local role authenticated;
select set_config('request.jwt.claim.sub', 'a0000000-0000-0000-0000-000000000001', true);

insert into beta_test_ids values (
  'conversation',
  public.create_conversation(
    'pickleball',
    array['b0000000-0000-0000-0000-000000000002'::uuid],
    null
  )
);

-- The creator is accepted immediately and can send the initial request message.
select public.send_chat_message(
  (select id from beta_test_ids where name = 'conversation'),
  'text',
  'Want to play?',
  '{}'::jsonb
);

-- A pending recipient cannot reply until accepting the conversation.
select set_config('request.jwt.claim.sub', 'b0000000-0000-0000-0000-000000000002', true);
do $$
begin
  perform public.send_chat_message(
    (select id from beta_test_ids where name = 'conversation'),
    'text', 'Premature reply', '{}'::jsonb
  );
  raise exception 'expected pending conversation reply to fail';
exception when insufficient_privilege then null;
end;
$$;

select public.accept_conversation((select id from beta_test_ids where name = 'conversation'));
select public.send_chat_message(
  (select id from beta_test_ids where name = 'conversation'),
  'text', 'Yes', '{}'::jsonb
);

-- Challenges work for a shared active sport and accepted connection.
select set_config('request.jwt.claim.sub', 'a0000000-0000-0000-0000-000000000001', true);
insert into beta_test_ids values (
  'challenge',
  public.create_challenge(
    'pickleball',
    'singles',
    '[{"user_id":"b0000000-0000-0000-0000-000000000002","team":2}]'::jsonb,
    jsonb_build_array(jsonb_build_object(
      'starts_at', now() + interval '1 day',
      'ends_at', now() + interval '2 hours 1 day'
    )),
    '', null, (select id from beta_test_ids where name = 'conversation'), false
  )
);

-- Maya has no active Badminton profile, so a crafted request must be rejected.
do $$
begin
  perform public.create_challenge(
    'badminton',
    'singles',
    '[{"user_id":"b0000000-0000-0000-0000-000000000002","team":2}]'::jsonb,
    jsonb_build_array(jsonb_build_object(
      'starts_at', now() + interval '1 day',
      'ends_at', now() + interval '2 hours 1 day'
    )),
    '', null, null, false
  );
  raise exception 'expected non-shared sport challenge to fail';
exception when others then
  if sqlerrm = 'expected non-shared sport challenge to fail' then raise; end if;
end;
$$;

-- Upload and unanimous verification settle one competitive rating exactly once.
insert into beta_test_ids values (
  'match',
  public.create_uploaded_match(
    'pickleball',
    'singles',
    '[{"user_id":"b0000000-0000-0000-0000-000000000002","team":2}]'::jsonb,
    now(),
    false
  )
);
select public.save_and_report_match_result(
  (select id from beta_test_ids where name = 'match'),
  1::smallint,
  '[{"team_one_score":11,"team_two_score":8}]'::jsonb
);

select set_config('request.jwt.claim.sub', 'b0000000-0000-0000-0000-000000000002', true);
select public.save_and_report_match_result(
  (select id from beta_test_ids where name = 'match'),
  1::smallint,
  '[{"team_one_score":11,"team_two_score":8}]'::jsonb
);

reset role;

do $$
begin
  if (select status from public.matches where id = (select id from beta_test_ids where name = 'match')) <> 'completed' then
    raise exception 'verified match was not completed';
  end if;
  if (select count(*) from public.rating_events where match_id = (select id from beta_test_ids where name = 'match')) <> 2 then
    raise exception 'expected one immutable rating event per participant';
  end if;
end;
$$;

select 'closed beta integrity checks passed' as result;
rollback;
