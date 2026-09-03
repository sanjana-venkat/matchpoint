-- Read model for a durable inbox. It returns only conversations the caller belongs to.
begin;

create or replace function public.my_inbox()
returns table (
  conversation_id uuid,
  sport public.sport_code,
  title text,
  updated_at timestamptz,
  is_request boolean,
  participant_ids uuid[],
  participant_names text[],
  participant_usernames text[],
  participant_avatar_ids text[],
  messages jsonb
) language sql stable security definer set search_path = '' as $$
  with mine as (
    select cm.conversation_id, cm.accepted_at
    from public.conversation_members cm where cm.user_id = auth.uid()
  )
  select c.id, c.sport, c.title, c.updated_at, mine.accepted_at is null,
    coalesce((select array_agg(p.id order by p.display_name)
      from public.conversation_members others join public.profiles p on p.id = others.user_id
      where others.conversation_id = c.id and others.user_id <> auth.uid()), array[]::uuid[]),
    coalesce((select array_agg(p.display_name order by p.display_name)
      from public.conversation_members others join public.profiles p on p.id = others.user_id
      where others.conversation_id = c.id and others.user_id <> auth.uid()), array[]::text[]),
    coalesce((select array_agg(p.username order by p.display_name)
      from public.conversation_members others join public.profiles p on p.id = others.user_id
      where others.conversation_id = c.id and others.user_id <> auth.uid()), array[]::text[]),
    coalesce((select array_agg(coalesce(p.avatar_id, '') order by p.display_name)
      from public.conversation_members others join public.profiles p on p.id = others.user_id
      where others.conversation_id = c.id and others.user_id <> auth.uid()), array[]::text[]),
    coalesce((select jsonb_agg(jsonb_build_object(
      'id', m.id, 'sender_id', m.sender_id, 'kind', m.kind, 'body', m.body,
      'payload', m.payload, 'created_at', m.created_at
    ) order by m.created_at)
      from public.messages m where m.conversation_id = c.id and m.deleted_at is null), '[]'::jsonb)
  from mine join public.conversations c on c.id = mine.conversation_id
  order by c.updated_at desc;
$$;

revoke all on function public.my_inbox() from public;
grant execute on function public.my_inbox() to authenticated;
comment on function public.my_inbox() is 'Durable caller-scoped inbox with members and ordered messages.';

commit;
