-- Run this once in Supabase: SQL Editor > New query > Run
-- Safe to re-run: it only adds what is missing.

create extension if not exists pgcrypto;

create table if not exists public.rooms (
  id           uuid primary key default gen_random_uuid(),
  code         text not null unique,
  status       text not null default 'waiting' check (status in ('waiting','playing','finished')),
  max_players  int  not null default 4,
  created_at   timestamptz not null default now(),
  round        int    not null default 0,          -- 0 = first match; resets to 0 when a player joins/leaves
  scores       jsonb  not null default '{}'::jsonb, -- { playerId: { w: wins, l: losses } }
  last_winner  uuid,                                -- winner of the previous round (leads the next one)
  game         jsonb,                               -- turn order, table cards, passes, winner/loser
  ver          bigint not null default 0            -- guards against two clients writing at once
);

create table if not exists public.players (
  id          uuid primary key default gen_random_uuid(),
  room_id     uuid not null references public.rooms(id) on delete cascade,
  name        text not null check (char_length(name) between 2 and 16),
  is_host     boolean not null default false,
  joined_at   timestamptz not null default now(),
  last_seen   timestamptz not null default now(),
  hand        jsonb,
  hand_round  int
);

-- If you created the tables with an earlier version, these add the new columns:
alter table public.rooms   add column if not exists round       int    not null default 0;
alter table public.rooms   add column if not exists scores      jsonb  not null default '{}'::jsonb;
alter table public.rooms   add column if not exists last_winner uuid;
alter table public.rooms   add column if not exists game        jsonb;
alter table public.rooms   add column if not exists ver         bigint not null default 0;
alter table public.players add column if not exists hand        jsonb;
alter table public.players add column if not exists hand_round  int;

create index if not exists players_room_idx on public.players(room_id);
create unique index if not exists players_room_name_uniq on public.players(room_id, lower(name));

-- Row Level Security: open to the anon key for now (prototype).
alter table public.rooms   enable row level security;
alter table public.players enable row level security;
drop policy if exists "rooms open"   on public.rooms;
drop policy if exists "players open" on public.players;
create policy "rooms open"   on public.rooms   for all to anon using (true) with check (true);
create policy "players open" on public.players for all to anon using (true) with check (true);

-- Realtime
alter table public.rooms   replica identity full;
alter table public.players replica identity full;
do $$ begin
  begin alter publication supabase_realtime add table public.rooms;   exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.players; exception when duplicate_object then null; end;
end $$;