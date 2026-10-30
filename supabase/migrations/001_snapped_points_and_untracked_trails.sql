-- Snapped routes and untracked trails.
-- Run this in the Supabase SQL editor on a project that already has schema.sql applied.

-- One row per walk_points row, holding the map-matched (snapped) position.
-- `sequence` lines up with walk_points.sequence. match_status records what the
-- matcher did with the point:
--   matched   - snapped onto a known street/sidewalk/trail
--   unmatched - nothing mapped nearby; lat/lng are the raw GPS position
--   rejected  - the snap would have moved the point too far; raw position kept
create table snapped_points (
  id bigint generated always as identity primary key,
  walk_id uuid not null references walks (id) on delete cascade,
  sequence integer not null,
  lat double precision not null,
  lng double precision not null,
  match_status text not null check (match_status in ('matched', 'unmatched', 'rejected')),
  unique (walk_id, sequence)
);

-- Stretches of a walk that look like trails missing from map data. A trail is
-- the run of snapped_points for its walk from start_sequence to end_sequence
-- (inclusive). Starts as a 'candidate'; 'accepted' once confirmed. To add a
-- type later, replace the check constraint.
create table untracked_trails (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  walk_id uuid not null references walks (id) on delete cascade,
  type text not null default 'candidate' check (type in ('candidate', 'accepted')),
  start_sequence integer not null,
  end_sequence integer not null,
  created_at timestamptz not null default now(),
  check (end_sequence >= start_sequence)
);

create index untracked_trails_user_type_idx on untracked_trails (user_id, type);
create index untracked_trails_walk_id_idx on untracked_trails (walk_id);

alter table snapped_points enable row level security;
alter table untracked_trails enable row level security;

create policy "snapped_points follow parent walk ownership"
  on snapped_points
  for all
  using (
    exists (
      select 1 from walks
      where walks.id = snapped_points.walk_id
      and walks.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from walks
      where walks.id = snapped_points.walk_id
      and walks.user_id = auth.uid()
    )
  );

create policy "untracked_trails are owned by user"
  on untracked_trails
  for all
  using (auth.uid() = user_id)
  with check (
    auth.uid() = user_id
    and exists (
      select 1 from walks
      where walks.id = untracked_trails.walk_id
      and walks.user_id = auth.uid()
    )
  );
