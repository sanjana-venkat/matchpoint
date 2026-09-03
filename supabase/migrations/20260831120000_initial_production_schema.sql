-- Match Point production schema.
-- Client access is denied by default and opened deliberately through RLS.

create extension if not exists pgcrypto;

create type public.sport_code as enum (
  'pickleball', 'badminton', 'pingPong', 'volleyball', 'cricket', 'soccer'
);
create type public.gender_code as enum ('male', 'female', 'nonBinary');
create type public.connection_status as enum ('pending', 'accepted', 'declined');
create type public.challenge_status as enum (
  'proposed', 'confirmed', 'awaitingResult', 'resultDisputed', 'completed', 'cancelled'
);
create type public.match_format as enum ('singles', 'doubles', 'group');
create type public.message_kind as enum ('text', 'image', 'location', 'challenge', 'match', 'system');
create type public.report_status as enum ('open', 'reviewing', 'resolved', 'dismissed');
create type public.account_deletion_status as enum ('requested', 'processing', 'completed', 'cancelled');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null,
  display_name text not null default '',
  birth_date date,
  gender public.gender_code,
  avatar_id text,
  bio text not null default '',
  city text not null default '',
  latitude double precision,
  longitude double precision,
  discovery_radius_miles smallint not null default 25 check (discovery_radius_miles between 1 and 100),
  is_discoverable boolean not null default true,
  onboarding_completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_username_format check (username ~ '^[a-z0-9_]{3,24}$'),
  constraint profiles_location_pair check ((latitude is null) = (longitude is null)),
  constraint profiles_latitude check (latitude is null or latitude between -90 and 90),
  constraint profiles_longitude check (longitude is null or longitude between -180 and 180)
);
create unique index profiles_username_unique on public.profiles (lower(username));
create index profiles_discovery_index on public.profiles (is_discoverable, city);

create table public.sport_profiles (
  user_id uuid not null references public.profiles(id) on delete cascade,
  sport public.sport_code not null,
  rating integer not null default 80 check (rating between 0 and 3000),
  rating_opt_out boolean not null default false,
  rating_version integer not null default 1,
  matches_played integer not null default 0 check (matches_played >= 0),
  partner_status text not null default 'solo',
  home_court text not null default '',
  owns_equipment boolean not null default true,
  played_tournaments boolean not null default false,
  self_assessment text not null default 'casual',
  social_skill_label text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, sport)
);
create index sport_profiles_discovery_index on public.sport_profiles (sport, is_active, rating);

create table public.peer_skill_ratings (
  id uuid primary key default gen_random_uuid(),
  subject_user_id uuid not null references public.profiles(id) on delete cascade,
  reviewer_user_id uuid not null references public.profiles(id) on delete cascade,
  sport public.sport_code not null,
  category text not null,
  score smallint not null check (score between 1 and 5),
  match_id uuid,
  created_at timestamptz not null default now(),
  unique (subject_user_id, reviewer_user_id, sport, category, match_id),
  check (subject_user_id <> reviewer_user_id)
);

create table public.availability_slots (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  recurrence_weekday smallint check (recurrence_weekday between 1 and 7),
  one_off_date date,
  start_time time not null,
  end_time time not null,
  timezone text not null default 'America/Chicago',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint availability_rule check ((recurrence_weekday is null) <> (one_off_date is null)),
  constraint availability_time_order check (start_time < end_time)
);
create index availability_user_index on public.availability_slots (user_id);

create table public.connections (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles(id) on delete cascade,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  status public.connection_status not null default 'pending',
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  user_low uuid generated always as (least(requester_id, recipient_id)) stored,
  user_high uuid generated always as (greatest(requester_id, recipient_id)) stored,
  check (requester_id <> recipient_id),
  unique (user_low, user_high)
);
create index connections_requester_index on public.connections (requester_id, status);
create index connections_recipient_index on public.connections (recipient_id, status);

create table public.blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  sport public.sport_code not null,
  title text,
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.conversation_members (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  accepted_at timestamptz,
  last_read_at timestamptz,
  muted_until timestamptz,
  primary key (conversation_id, user_id)
);
create index conversation_members_user_index on public.conversation_members (user_id, conversation_id);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid references public.profiles(id) on delete set null,
  kind public.message_kind not null default 'text',
  body text,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  edited_at timestamptz,
  deleted_at timestamptz,
  constraint message_content_present check (body is not null or payload <> '{}'::jsonb)
);
create index messages_conversation_index on public.messages (conversation_id, created_at desc);

create table public.challenges (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid references public.conversations(id) on delete set null,
  created_by uuid not null references public.profiles(id) on delete restrict,
  sport public.sport_code not null,
  format public.match_format not null default 'singles',
  status public.challenge_status not null default 'proposed',
  note text not null default '',
  venue_name text,
  selected_slot_id uuid,
  revision integer not null default 1 check (revision > 0),
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.challenge_participants (
  challenge_id uuid not null references public.challenges(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  team smallint check (team in (1, 2)),
  accepted_at timestamptz,
  declined_at timestamptz,
  primary key (challenge_id, user_id)
);
create index challenge_participants_user_index on public.challenge_participants (user_id, challenge_id);

create table public.challenge_slots (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.challenges(id) on delete cascade,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  proposed_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  check (starts_at < ends_at)
);
alter table public.challenges
  add constraint challenges_selected_slot_fk
  foreign key (selected_slot_id) references public.challenge_slots(id) on delete set null;

create table public.matches (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid unique references public.challenges(id) on delete set null,
  sport public.sport_code not null,
  format public.match_format not null,
  status public.challenge_status not null default 'confirmed',
  starts_at timestamptz not null,
  ends_at timestamptz,
  venue_name text,
  rating_exempt boolean not null default false,
  rating_algorithm_version integer not null default 1,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.match_participants (
  match_id uuid not null references public.matches(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  team smallint not null check (team in (1, 2)),
  rating_before integer,
  rating_after integer,
  result_reported_team smallint check (result_reported_team in (1, 2)),
  reported_at timestamptz,
  confirmed_at timestamptz,
  primary key (match_id, user_id)
);
create index match_participants_user_index on public.match_participants (user_id, match_id);

create table public.game_scores (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  game_number smallint not null check (game_number > 0),
  team_one_score smallint not null check (team_one_score >= 0),
  team_two_score smallint not null check (team_two_score >= 0),
  created_at timestamptz not null default now(),
  unique (match_id, game_number),
  check (team_one_score <> team_two_score)
);

create table public.rating_events (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete restrict,
  user_id uuid not null references public.profiles(id) on delete cascade,
  sport public.sport_code not null,
  rating_before integer not null,
  rating_after integer not null,
  expected_score numeric(7,6) not null check (expected_score between 0 and 1),
  actual_score numeric(2,1) not null check (actual_score in (0, 0.5, 1)),
  algorithm_version integer not null,
  inputs jsonb not null default '{}'::jsonb,
  supersedes_event_id uuid references public.rating_events(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (match_id, user_id, algorithm_version)
);
create index rating_events_user_index on public.rating_events (user_id, sport, created_at desc);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid references public.profiles(id) on delete set null,
  reported_user_id uuid references public.profiles(id) on delete set null,
  conversation_id uuid references public.conversations(id) on delete set null,
  message_id uuid references public.messages(id) on delete set null,
  category text not null,
  details text not null default '',
  status public.report_status not null default 'open',
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);
create index reports_status_index on public.reports (status, created_at);

create table public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  token text not null,
  platform text not null check (platform in ('ios', 'android')),
  environment text not null check (environment in ('development', 'production')),
  last_seen_at timestamptz not null default now(),
  unique (user_id, token)
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null,
  payload jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index notifications_user_index on public.notifications (user_id, read_at, created_at desc);

create table public.account_deletion_requests (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  status public.account_deletion_status not null default 'requested',
  requested_at timestamptz not null default now(),
  process_after timestamptz not null default (now() + interval '7 days'),
  completed_at timestamptz
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at before update on public.profiles
for each row execute function public.set_updated_at();
create trigger sport_profiles_set_updated_at before update on public.sport_profiles
for each row execute function public.set_updated_at();
create trigger availability_set_updated_at before update on public.availability_slots
for each row execute function public.set_updated_at();
create trigger conversations_set_updated_at before update on public.conversations
for each row execute function public.set_updated_at();
create trigger challenges_set_updated_at before update on public.challenges
for each row execute function public.set_updated_at();
create trigger matches_set_updated_at before update on public.matches
for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, username, display_name)
  values (
    new.id,
    'player_' || left(replace(new.id::text, '-', ''), 8),
    coalesce(new.raw_user_meta_data ->> 'display_name', '')
  );
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

create or replace function public.is_conversation_member(target_conversation_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.conversation_members
    where conversation_id = target_conversation_id and user_id = (select auth.uid())
  );
$$;

create or replace function public.is_challenge_participant(target_challenge_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.challenge_participants
    where challenge_id = target_challenge_id and user_id = (select auth.uid())
  );
$$;

create or replace function public.is_match_participant(target_match_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.match_participants
    where match_id = target_match_id and user_id = (select auth.uid())
  );
$$;

revoke all on function public.is_conversation_member(uuid) from public;
revoke all on function public.is_challenge_participant(uuid) from public;
revoke all on function public.is_match_participant(uuid) from public;
grant execute on function public.is_conversation_member(uuid) to authenticated;
grant execute on function public.is_challenge_participant(uuid) to authenticated;
grant execute on function public.is_match_participant(uuid) to authenticated;

alter table public.profiles enable row level security;
alter table public.sport_profiles enable row level security;
alter table public.peer_skill_ratings enable row level security;
alter table public.availability_slots enable row level security;
alter table public.connections enable row level security;
alter table public.blocks enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;
alter table public.challenges enable row level security;
alter table public.challenge_participants enable row level security;
alter table public.challenge_slots enable row level security;
alter table public.matches enable row level security;
alter table public.match_participants enable row level security;
alter table public.game_scores enable row level security;
alter table public.rating_events enable row level security;
alter table public.reports enable row level security;
alter table public.device_tokens enable row level security;
alter table public.notifications enable row level security;
alter table public.account_deletion_requests enable row level security;

create policy "authenticated profiles are discoverable"
on public.profiles for select to authenticated
using (id = (select auth.uid()) or is_discoverable);
create policy "users update own profile"
on public.profiles for update to authenticated
using (id = (select auth.uid())) with check (id = (select auth.uid()));

create policy "authenticated users view active sport profiles"
on public.sport_profiles for select to authenticated
using (user_id = (select auth.uid()) or is_active);
create policy "users insert own sport profiles"
on public.sport_profiles for insert to authenticated
with check (user_id = (select auth.uid()));
create policy "users update own sport profile settings"
on public.sport_profiles for update to authenticated
using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "users delete own sport profiles"
on public.sport_profiles for delete to authenticated
using (user_id = (select auth.uid()));

create policy "users view ratings involving themselves"
on public.peer_skill_ratings for select to authenticated
using (subject_user_id = (select auth.uid()) or reviewer_user_id = (select auth.uid()));
create policy "users submit peer ratings"
on public.peer_skill_ratings for insert to authenticated
with check (reviewer_user_id = (select auth.uid()));

create policy "users view own and connected availability"
on public.availability_slots for select to authenticated
using (
  user_id = (select auth.uid()) or exists (
    select 1 from public.connections c
    where c.status = 'accepted'
      and ((c.requester_id = (select auth.uid()) and c.recipient_id = user_id)
        or (c.recipient_id = (select auth.uid()) and c.requester_id = user_id))
  )
);
create policy "users manage own availability"
on public.availability_slots for all to authenticated
using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create policy "users view their connections"
on public.connections for select to authenticated
using (requester_id = (select auth.uid()) or recipient_id = (select auth.uid()));
create policy "users create connection requests"
on public.connections for insert to authenticated
with check (requester_id = (select auth.uid()) and status = 'pending');
create policy "recipients respond to requests"
on public.connections for update to authenticated
using (recipient_id = (select auth.uid())) with check (recipient_id = (select auth.uid()));
create policy "participants delete connections"
on public.connections for delete to authenticated
using (requester_id = (select auth.uid()) or recipient_id = (select auth.uid()));

create policy "users view own blocks"
on public.blocks for select to authenticated using (blocker_id = (select auth.uid()));
create policy "users create own blocks"
on public.blocks for insert to authenticated with check (blocker_id = (select auth.uid()));
create policy "users remove own blocks"
on public.blocks for delete to authenticated using (blocker_id = (select auth.uid()));

create policy "members view conversations"
on public.conversations for select to authenticated using (public.is_conversation_member(id));
create policy "authenticated users create conversations"
on public.conversations for insert to authenticated with check (created_by = (select auth.uid()));
create policy "creators update conversations"
on public.conversations for update to authenticated
using (created_by = (select auth.uid())) with check (created_by = (select auth.uid()));

create policy "members view conversation membership"
on public.conversation_members for select to authenticated
using (public.is_conversation_member(conversation_id));
create policy "conversation creators add members"
on public.conversation_members for insert to authenticated
with check (exists (
  select 1 from public.conversations c
  where c.id = conversation_id and c.created_by = (select auth.uid())
));
create policy "members update own membership"
on public.conversation_members for update to authenticated
using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create policy "members view messages"
on public.messages for select to authenticated using (public.is_conversation_member(conversation_id));
create policy "members send messages"
on public.messages for insert to authenticated
with check (sender_id = (select auth.uid()) and public.is_conversation_member(conversation_id));
create policy "senders soft-delete own messages"
on public.messages for update to authenticated
using (sender_id = (select auth.uid())) with check (sender_id = (select auth.uid()));

create policy "participants view challenges"
on public.challenges for select to authenticated using (public.is_challenge_participant(id));
create policy "authenticated users create challenges"
on public.challenges for insert to authenticated with check (created_by = (select auth.uid()));
create policy "challenge creators update drafts"
on public.challenges for update to authenticated
using (created_by = (select auth.uid()) and status = 'proposed')
with check (created_by = (select auth.uid()));

create policy "participants view challenge membership"
on public.challenge_participants for select to authenticated
using (public.is_challenge_participant(challenge_id));
create policy "challenge creators add participants"
on public.challenge_participants for insert to authenticated
with check (exists (
  select 1 from public.challenges c
  where c.id = challenge_id and c.created_by = (select auth.uid())
));
create policy "participants respond to challenges"
on public.challenge_participants for update to authenticated
using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create policy "participants view challenge slots"
on public.challenge_slots for select to authenticated using (public.is_challenge_participant(challenge_id));
create policy "participants propose challenge slots"
on public.challenge_slots for insert to authenticated
with check (proposed_by = (select auth.uid()) and public.is_challenge_participant(challenge_id));

create policy "participants view matches"
on public.matches for select to authenticated using (public.is_match_participant(id));
create policy "participants view match membership"
on public.match_participants for select to authenticated using (public.is_match_participant(match_id));
create policy "participants report own result"
on public.match_participants for update to authenticated
using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "participants view game scores"
on public.game_scores for select to authenticated using (public.is_match_participant(match_id));
create policy "participants submit game scores"
on public.game_scores for insert to authenticated
with check (public.is_match_participant(match_id));
create policy "users view own rating events"
on public.rating_events for select to authenticated using (user_id = (select auth.uid()));

create policy "users create reports"
on public.reports for insert to authenticated with check (reporter_id = (select auth.uid()));
create policy "users view own reports"
on public.reports for select to authenticated using (reporter_id = (select auth.uid()));

create policy "users manage own device tokens"
on public.device_tokens for all to authenticated
using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "users view own notifications"
on public.notifications for select to authenticated using (user_id = (select auth.uid()));
create policy "users mark own notifications read"
on public.notifications for update to authenticated
using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "users request own account deletion"
on public.account_deletion_requests for insert to authenticated
with check (user_id = (select auth.uid()) and status = 'requested');
create policy "users view own deletion request"
on public.account_deletion_requests for select to authenticated using (user_id = (select auth.uid()));
create policy "users cancel pending deletion request"
on public.account_deletion_requests for update to authenticated
using (user_id = (select auth.uid()) and status = 'requested')
with check (user_id = (select auth.uid()) and status in ('requested', 'cancelled'));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', true, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

create policy "public avatar reads"
on storage.objects for select to public using (bucket_id = 'avatars');
create policy "users upload own avatars"
on storage.objects for insert to authenticated
with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "users update own avatars"
on storage.objects for update to authenticated
using (bucket_id = 'avatars' and owner_id = (select auth.uid())::text)
with check (bucket_id = 'avatars' and owner_id = (select auth.uid())::text);
create policy "users delete own avatars"
on storage.objects for delete to authenticated
using (bucket_id = 'avatars' and owner_id = (select auth.uid())::text);

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'messages'
  ) then alter publication supabase_realtime add table public.messages; end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'notifications'
  ) then alter publication supabase_realtime add table public.notifications; end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'challenges'
  ) then alter publication supabase_realtime add table public.challenges; end if;
end $$;

revoke all on all tables in schema public from anon;
grant usage on schema public to authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
alter default privileges in schema public grant select, insert, update, delete on tables to authenticated;
