-- Trail MVP schema
-- Run this in the Supabase SQL editor (Dashboard > SQL Editor > New query) on a fresh project.

create extension if not exists "pgcrypto";

create table walks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  started_at timestamptz not null,
  ended_at timestamptz not null,
  distance_meters double precision not null default 0,
  duration_seconds integer not null default 0,
  created_at timestamptz not null default now()
);

create table walk_points (
  id bigint generated always as identity primary key,
  walk_id uuid not null references walks (id) on delete cascade,
  lat double precision not null,
  lng double precision not null,
  altitude double precision,
  recorded_at timestamptz not null,
  sequence integer not null
);

create index walk_points_walk_id_idx on walk_points (walk_id, sequence);
create index walks_user_id_idx on walks (user_id, started_at desc);

-- Row Level Security: each user can only see/write their own walks and points.

alter table walks enable row level security;
alter table walk_points enable row level security;

create policy "walks are owned by user"
  on walks
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "walk_points follow parent walk ownership"
  on walk_points
  for all
  using (
    exists (
      select 1 from walks
      where walks.id = walk_points.walk_id
      and walks.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from walks
      where walks.id = walk_points.walk_id
      and walks.user_id = auth.uid()
    )
  );
