-- Account-scoped cloud storage so signed-in riders see the same data on every
-- device. Ride sessions (with telemetry), gamification progress, activity
-- goals, emergency contacts, and logistics/budget data all become part of the
-- account instead of living only on one device.

-- Generic JSONB settings document per account. Used for activity goals,
-- emergency contacts, and logistics/budget data.
create table if not exists public.account_settings (
  user_id uuid not null references public.app_users(id) on delete cascade,
  key text not null check (char_length(key) between 1 and 64),
  value jsonb not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, key)
);

alter table public.account_settings enable row level security;
revoke all on table public.account_settings from public, anon, authenticated;
grant select, insert, update, delete
  on table public.account_settings to authenticated;

create policy "Users can read their own account settings"
  on public.account_settings for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Users can create their own account settings"
  on public.account_settings for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "Users can update their own account settings"
  on public.account_settings for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "Users can delete their own account settings"
  on public.account_settings for delete to authenticated
  using ((select auth.uid()) = user_id);

-- Full ride session metadata. Supersedes the summary-only cloud copy for
-- account sync while ride_session_summaries remains for team/leaderboard use.
create table if not exists public.ride_sessions (
  user_id uuid not null references public.app_users(id) on delete cascade,
  session_id uuid not null,
  title text not null default '' check (char_length(title) <= 60),
  activity_type text not null default 'ride'
    check (activity_type in ('ride', 'commute', 'training', 'race')),
  source text not null default 'recorded'
    check (char_length(source) between 1 and 32),
  started_at timestamptz not null,
  ended_at timestamptz not null,
  total_paused_ms bigint not null default 0
    check (total_paused_ms between 0 and 604800000),
  distance_meters double precision not null
    check (
      distance_meters >= 0
      and distance_meters < 1000000
      and distance_meters < 'Infinity'::double precision
    ),
  gps_accuracy_meters double precision
    check (
      gps_accuracy_meters is null
      or (gps_accuracy_meters >= 0 and gps_accuracy_meters < 100000)
    ),
  updated_at timestamptz not null default now(),
  primary key (user_id, session_id),
  check (ended_at >= started_at)
);

alter table public.ride_sessions enable row level security;
revoke all on table public.ride_sessions from public, anon, authenticated;
grant select, insert, update, delete
  on table public.ride_sessions to authenticated;

create policy "Users can read their own ride sessions"
  on public.ride_sessions for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Users can create their own ride sessions"
  on public.ride_sessions for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "Users can update their own ride sessions"
  on public.ride_sessions for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "Users can delete their own ride sessions"
  on public.ride_sessions for delete to authenticated
  using ((select auth.uid()) = user_id);

-- GPS/telemetry track points for a ride session. Points are uploaded in plain
-- JSON over TLS and protected by row level security; the cloud is the single
-- source of truth so any device can restore the exact ride.
create table if not exists public.ride_session_telemetry (
  user_id uuid not null,
  session_id uuid not null,
  point_index integer not null check (point_index >= 0),
  recorded_at timestamptz not null,
  latitude double precision not null
    check (latitude >= -90 and latitude <= 90),
  longitude double precision not null
    check (longitude >= -180 and longitude <= 180),
  accuracy_meters double precision not null
    check (accuracy_meters >= 0 and accuracy_meters < 100000),
  altitude_meters double precision not null,
  altitude_accuracy_meters double precision,
  barometric_pressure_hpa double precision,
  acceleration_magnitude double precision,
  rotation_rate_magnitude double precision,
  speed_meters_per_second double precision not null
    check (
      speed_meters_per_second >= 0
      and speed_meters_per_second < 100
    ),
  primary key (user_id, session_id, point_index),
  foreign key (user_id, session_id)
    references public.ride_sessions(user_id, session_id) on delete cascade
);

alter table public.ride_session_telemetry enable row level security;
revoke all on table public.ride_session_telemetry
  from public, anon, authenticated;
grant select, insert, update, delete
  on table public.ride_session_telemetry to authenticated;

create policy "Users can read their own ride telemetry"
  on public.ride_session_telemetry for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Users can create their own ride telemetry"
  on public.ride_session_telemetry for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "Users can update their own ride telemetry"
  on public.ride_session_telemetry for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "Users can delete their own ride telemetry"
  on public.ride_session_telemetry for delete to authenticated
  using ((select auth.uid()) = user_id);

-- Extended gamification progress persisted with the profile so achievements
-- and rider stats survive reinstalls and appear on every signed-in device.
alter table public.rider_profiles
  add column if not exists distance_meters double precision not null default 0
    check (
      distance_meters >= 0
      and distance_meters < 'Infinity'::double precision
    ),
  add column if not exists completed_rides integer not null default 0
    check (completed_rides between 0 and 1000000),
  add column if not exists ride_duration_seconds bigint not null default 0
    check (ride_duration_seconds between 0 and 1000000000),
  add column if not exists weekend_rides integer not null default 0
    check (weekend_rides between 0 and 1000000),
  add column if not exists appearance jsonb;

create or replace function public.set_my_rider_progress(
  p_rider_style text,
  p_rider_level integer,
  p_experience bigint,
  p_distance_meters double precision,
  p_completed_rides integer,
  p_ride_duration_seconds bigint,
  p_weekend_rides integer,
  p_appearance jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
begin
  if v_user_id is null then
    raise exception 'Authentication is required.';
  end if;
  if p_rider_style not in ('sprinter', 'climber', 'explorer', 'ace') then
    raise exception 'Invalid rider style.';
  end if;
  if p_rider_level not between 1 and 100000
    or p_experience not between 0 and 1000000000
    or p_distance_meters is null
    or p_distance_meters < 0
    or p_distance_meters >= 'Infinity'::double precision
    or p_completed_rides is null
    or p_completed_rides not between 0 and 1000000
    or p_ride_duration_seconds is null
    or p_ride_duration_seconds not between 0 and 1000000000
    or p_weekend_rides is null
    or p_weekend_rides not between 0 and 1000000
  then
    raise exception 'Invalid rider progress.';
  end if;

  insert into public.rider_profiles (
    user_id, rider_style, rider_level, experience,
    distance_meters, completed_rides, ride_duration_seconds, weekend_rides,
    appearance, updated_at
  )
  values (
    v_user_id, p_rider_style, p_rider_level, p_experience,
    p_distance_meters, p_completed_rides, p_ride_duration_seconds,
    p_weekend_rides, p_appearance, now()
  )
  on conflict (user_id) do update
    set rider_style = excluded.rider_style,
        rider_level = greatest(
          public.rider_profiles.rider_level,
          excluded.rider_level
        ),
        experience = greatest(
          public.rider_profiles.experience,
          excluded.experience
        ),
        distance_meters = greatest(
          public.rider_profiles.distance_meters,
          excluded.distance_meters
        ),
        completed_rides = greatest(
          public.rider_profiles.completed_rides,
          excluded.completed_rides
        ),
        ride_duration_seconds = greatest(
          public.rider_profiles.ride_duration_seconds,
          excluded.ride_duration_seconds
        ),
        weekend_rides = greatest(
          public.rider_profiles.weekend_rides,
          excluded.weekend_rides
        ),
        appearance = coalesce(
          excluded.appearance,
          public.rider_profiles.appearance
        ),
        updated_at = now();
end;
$$;

revoke all on function public.set_my_rider_progress(
  text, integer, bigint, double precision, integer, bigint, integer, jsonb
) from public, anon;
grant execute on function public.set_my_rider_progress(
  text, integer, bigint, double precision, integer, bigint, integer, jsonb
) to authenticated;
