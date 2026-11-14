-- Run this once in Supabase: SQL Editor > New query > Run

create extension if not exists pgcrypto;

create table if not exists public.rooms (
  id          uuid primary key default gen_random_uuid(),
  code        text not null unique,
  status      text not null default 'waiting' check (status in ('waiting','playing','finished')),
  max_players int  not null default 4,
  created_at  timestamptz not null default now()
);

create table if not exists public.players (
  id         uuid primary key default gen_random_uuid(),
  room_id    uuid not null references public.rooms(id) on delete cascade,
  name       text not null check (char_length(name) between 2 and 16),
  is_host    boolean not null default false,
  joined_at  timestamptz not null default now(),
  last_seen  timestamptz not null default now()
);

create index if not exists players_room_idx on public.players(room_id);
create unique index if not exists players_room_name_uniq on public.players(room_id, lower(name));

-- Row Level Security: open to the anon key for now (prototype).
alter table public.rooms   enable row level security;
alter table public.players enable row level security;
create policy "rooms open"   on public.rooms   for all to anon using (true) with check (true);
create policy "players open" on public.players for all to anon using (true) with check (true);

-- Realtime (lobby updates instantly when players join, leave or the game starts)
alter table public.rooms   replica identity full;
alter table public.players replica identity full;
alter publication supabase_realtime add table public.rooms, public.players;
