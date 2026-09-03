-- Keep the first beta limited to two live sports and persist inbox actions.
begin;

update public.sport_profiles set is_active = false
where sport not in ('pickleball', 'badminton') and is_active;

create or replace function public.enforce_two_sport_beta()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.sport not in ('pickleball', 'badminton') then
    if tg_table_name = 'sport_profiles' and not new.is_active then return new; end if;
    raise exception '% is coming soon', new.sport;
  end if;
  return new;
end;
$$;

drop trigger if exists enforce_beta_sport_profiles on public.sport_profiles;
create trigger enforce_beta_sport_profiles before insert or update on public.sport_profiles
for each row execute function public.enforce_two_sport_beta();
drop trigger if exists enforce_beta_challenges on public.challenges;
create trigger enforce_beta_challenges before insert or update on public.challenges
for each row execute function public.enforce_two_sport_beta();
drop trigger if exists enforce_beta_matches on public.matches;
create trigger enforce_beta_matches before insert or update on public.matches
for each row execute function public.enforce_two_sport_beta();

create or replace function public.accept_conversation(p_conversation_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  update public.conversation_members set accepted_at = coalesce(accepted_at, now())
  where conversation_id = p_conversation_id and user_id = auth.uid();
  if not found then raise exception 'conversation not found'; end if;
end;
$$;

create or replace function public.leave_conversation(p_conversation_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  delete from public.conversation_members where conversation_id = p_conversation_id and user_id = auth.uid();
  if not found then raise exception 'conversation not found'; end if;
  delete from public.conversations c where c.id = p_conversation_id
    and not exists (select 1 from public.conversation_members cm where cm.conversation_id = c.id);
end;
$$;

revoke all on function public.accept_conversation(uuid) from public;
revoke all on function public.leave_conversation(uuid) from public;
grant execute on function public.accept_conversation(uuid) to authenticated;
grant execute on function public.leave_conversation(uuid) to authenticated;

commit;
