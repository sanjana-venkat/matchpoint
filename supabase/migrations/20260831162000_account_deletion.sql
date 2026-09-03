begin;
create or replace function public.delete_my_account()
returns void language plpgsql security definer set search_path = '' as $$
declare v_user_id uuid := auth.uid();
begin
  if v_user_id is null then raise exception using message = 'Authentication required'; end if;
  -- The auth-user cascade removes the profile and every user-owned row.
  delete from auth.users where id = v_user_id;
  if not found then raise exception using message = 'Account not found'; end if;
end;
$$;
revoke all on function public.delete_my_account() from public;
grant execute on function public.delete_my_account() to authenticated;
comment on function public.delete_my_account() is
  'Permanently deletes the caller after an explicit in-app confirmation. Profile data cascades from auth.users.';
commit;
