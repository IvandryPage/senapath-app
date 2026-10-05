create table if not exists public.ride_session_summaries (
  user_id uuid not null references auth.users(id) on delete cascade,
  session_id uuid not null,
  started_at timestamptz not null,
  ended_at timestamptz not null,
  duration_seconds bigint not null check (duration_seconds >= 0),
  distance_meters double precision not null
    check (distance_meters >= 0 and distance_meters < 'Infinity'::float8),
  sample_count integer not null check (sample_count >= 0),
  elevation_gain_meters double precision
    check (
      elevation_gain_meters is null
      or (
        elevation_gain_meters >= 0
        and elevation_gain_meters < 'Infinity'::float8
      )
    ),
  elevation_source text not null
    check (char_length(elevation_source) between 1 and 80),
  accelerometer_sample_count integer not null
    check (accelerometer_sample_count >= 0),
  gyroscope_sample_count integer not null
    check (gyroscope_sample_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, session_id),
  check (ended_at >= started_at)
);

alter table public.ride_session_summaries enable row level security;

revoke all on table public.ride_session_summaries from anon, authenticated;
grant select, insert, update, delete
  on table public.ride_session_summaries to authenticated;

create policy "Users can read their own ride summaries"
  on public.ride_session_summaries
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can create their own ride summaries"
  on public.ride_session_summaries
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy "Users can update their own ride summaries"
  on public.ride_session_summaries
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Users can delete their own ride summaries"
  on public.ride_session_summaries
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);
