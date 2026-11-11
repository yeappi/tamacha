-- Conversation memory and multi-bubble responses for tamacha AI test users.
-- Uses existing rooms, messages, bot_personas and chat_locks tables.
create table if not exists public.bot_conversation_states (
  room_id uuid primary key references public.rooms(id) on delete cascade,
  state jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
alter table public.bot_conversation_states enable row level security;
revoke all on public.bot_conversation_states from public, anon, authenticated;
grant select, insert, update, delete on public.bot_conversation_states to service_role;

create or replace function public.finish_ai_turn(
  p_room uuid, p_source uuid, p_messages jsonb, p_state jsonb
) returns integer
language plpgsql security definer set search_path = ''
as $fn$
declare
  v_room public.rooms%rowtype;
  v_src public.messages%rowtype;
  v_bot uuid;
  v_lock uuid;
  v_part jsonb;
  v_body text;
  v_count integer;
  v_index integer := 0;
begin
  if p_messages is null or jsonb_typeof(p_messages) <> 'array' then
    raise exception 'Invalid reply message array';
  end if;
  v_count := jsonb_array_length(p_messages);
  if v_count > 3 then raise exception 'Too many reply messages'; end if;
  if p_state is not null and (jsonb_typeof(p_state) <> 'object' or length(p_state::text) > 5500) then
    raise exception 'Invalid conversation memory';
  end if;

  select * into v_room from public.rooms where id = p_room for update;
  if not found then raise exception 'Room not found'; end if;
  select * into v_src from public.messages where id = p_source and room_id = p_room;
  if not found then raise exception 'Source not found'; end if;
  if exists(select 1 from public.bot_personas where user_id = v_room.user_a) then v_bot := v_room.user_a; end if;
  if exists(select 1 from public.bot_personas where user_id = v_room.user_b) then
    if v_bot is not null then raise exception 'AI-only chat not allowed'; end if;
    v_bot := v_room.user_b;
  end if;
  if v_bot is null or v_src.sender_id = v_bot then raise exception 'Invalid participants'; end if;
  if (select id from public.messages where room_id = p_room order by created_at desc, id desc limit 1) <> p_source then
    raise exception 'Newer message exists';
  end if;
  select id into v_lock from public.chat_locks
    where segment_id = v_src.segment_id and expires_at > now()
    order by created_at desc limit 1;

  for v_part in select value from jsonb_array_elements(p_messages) as t(value)
  loop
    if jsonb_typeof(v_part) <> 'string' then raise exception 'Invalid message type'; end if;
    v_body := trim(v_part #>> '{}');
    if char_length(v_body) not between 1 and 300 then
      raise exception 'Invalid AI reply length';
    end if;
    insert into public.messages(room_id, segment_id, sender_id, body, lock_id, created_at)
      values(p_room, v_src.segment_id, v_bot, v_body, v_lock,
        clock_timestamp() + v_index * interval '1 millisecond');
    v_index := v_index + 1;
  end loop;
  if v_lock is not null and v_count > 0 then
    update public.chat_locks set message_count = message_count + v_count where id = v_lock;
  end if;
  if v_count > 0 then update public.rooms set last_message_at = now() where id = p_room; end if;
  if p_state is not null then
    insert into public.bot_conversation_states(room_id, state, updated_at)
      values(p_room, p_state, now())
    on conflict(room_id) do update set state = excluded.state, updated_at = excluded.updated_at;
  end if;
  return v_count;
end
$fn$;
revoke all on function public.finish_ai_turn(uuid,uuid,jsonb,jsonb) from public, anon, authenticated;
grant execute on function public.finish_ai_turn(uuid,uuid,jsonb,jsonb) to service_role;
-- The old single-reply function is now server-only.
revoke all on function public.finish_ai_reply(uuid,uuid,text) from public, anon, authenticated;
grant execute on function public.finish_ai_reply(uuid,uuid,text) to service_role;
