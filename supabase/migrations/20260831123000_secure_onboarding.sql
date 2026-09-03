-- Keep onboarding atomic and prevent clients from assigning their own rating.

drop policy if exists "users insert own sport profiles" on public.sport_profiles;
drop policy if exists "users update own sport profile settings" on public.sport_profiles;
drop policy if exists "users delete own sport profiles" on public.sport_profiles;

revoke insert, update, delete on public.sport_profiles from authenticated;

create or replace function public.complete_onboarding(
  p_username text,
  p_display_name text,
  p_birth_date date,
  p_gender text,
  p_avatar_id text,
  p_bio text,
  p_city text,
  p_sports jsonb,
  p_availability jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  sport_item jsonb;
  slot_item jsonb;
  selected_sport public.sport_code;
begin
  if current_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if p_username !~ '^[a-z0-9_]{3,24}$' then
    raise exception 'Username must contain 3-24 lowercase letters, numbers, or underscores'
      using errcode = '22023';
  end if;

  if jsonb_typeof(p_sports) <> 'array' or jsonb_array_length(p_sports) = 0 then
    raise exception 'Choose at least one sport' using errcode = '22023';
  end if;

  if jsonb_array_length(p_sports) > 4 then
    raise exception 'Choose no more than four sports' using errcode = '22023';
  end if;

  insert into public.profiles (
    id, username, display_name, birth_date, gender, avatar_id, bio, city
  ) values (
    current_user_id,
    p_username,
    trim(p_display_name),
    p_birth_date,
    p_gender::public.gender_code,
    nullif(trim(p_avatar_id), ''),
    coalesce(p_bio, ''),
    coalesce(p_city, '')
  )
  on conflict (id) do update set
    username = excluded.username,
    display_name = excluded.display_name,
    birth_date = excluded.birth_date,
    gender = excluded.gender,
    avatar_id = excluded.avatar_id,
    bio = excluded.bio,
    city = excluded.city;

  update public.sport_profiles
  set is_active = false
  where user_id = current_user_id;

  for sport_item in select value from jsonb_array_elements(p_sports)
  loop
    selected_sport := (sport_item ->> 'sport')::public.sport_code;

    insert into public.sport_profiles (
      user_id,
      sport,
      rating,
      rating_opt_out,
      partner_status,
      home_court,
      owns_equipment,
      played_tournaments,
      self_assessment,
      social_skill_label,
      is_active
    ) values (
      current_user_id,
      selected_sport,
      80,
      coalesce((sport_item ->> 'rating_opt_out')::boolean, false),
      coalesce(sport_item ->> 'partner_status', 'solo'),
      coalesce(sport_item ->> 'home_court', ''),
      coalesce((sport_item ->> 'owns_equipment')::boolean, true),
      coalesce((sport_item ->> 'played_tournaments')::boolean, false),
      coalesce(sport_item ->> 'self_assessment', 'casual'),
      nullif(sport_item ->> 'social_skill_label', ''),
      true
    )
    on conflict (user_id, sport) do update set
      rating_opt_out = excluded.rating_opt_out,
      partner_status = excluded.partner_status,
      home_court = excluded.home_court,
      owns_equipment = excluded.owns_equipment,
      played_tournaments = excluded.played_tournaments,
      self_assessment = excluded.self_assessment,
      social_skill_label = excluded.social_skill_label,
      is_active = true;
  end loop;

  delete from public.availability_slots where user_id = current_user_id;

  for slot_item in select value from jsonb_array_elements(coalesce(p_availability, '[]'::jsonb))
  loop
    insert into public.availability_slots (
      id,
      user_id,
      recurrence_weekday,
      one_off_date,
      start_time,
      end_time,
      timezone
    ) values (
      coalesce((slot_item ->> 'id')::uuid, gen_random_uuid()),
      current_user_id,
      (slot_item ->> 'recurrence_weekday')::smallint,
      (slot_item ->> 'one_off_date')::date,
      (slot_item ->> 'start_time')::time,
      (slot_item ->> 'end_time')::time,
      coalesce(nullif(slot_item ->> 'timezone', ''), 'UTC')
    );
  end loop;

  update public.profiles
  set onboarding_completed_at = now()
  where id = current_user_id;
end;
$$;

revoke all on function public.complete_onboarding(
  text, text, date, text, text, text, text, jsonb, jsonb
) from public;
grant execute on function public.complete_onboarding(
  text, text, date, text, text, text, text, jsonb, jsonb
) to authenticated;
