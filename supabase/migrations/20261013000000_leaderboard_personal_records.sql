alter table public.rider_profiles
  add column longest_ride_duration_seconds bigint not null default 0
    check (longest_ride_duration_seconds between 0 and 172800),
  add column longest_ride_distance_meters double precision not null default 0
    check (
      longest_ride_distance_meters >= 0
      and longest_ride_distance_meters < 1000000
      and longest_ride_distance_meters < 'Infinity'::double precision
    );

alter table public.leaderboard_preferences
  drop constraint if exists leaderboard_preferences_check,
  drop column if exists public_alias;

update public.rider_profiles profile
set longest_ride_duration_seconds = greatest(
      profile.longest_ride_duration_seconds,
      coalesce(history.longest_duration, 0)
    ),
    longest_ride_distance_meters = greatest(
      profile.longest_ride_distance_meters,
      coalesce(history.longest_distance, 0)
    )
from (
  select
    user_id,
    max(duration_seconds) filter (
      where duration_seconds between 1 and 172800
    ) as longest_duration,
    max(distance_meters) filter (
      where distance_meters > 0 and distance_meters < 1000000
    ) as longest_distance
  from public.ride_session_summaries
  group by user_id
) history
where history.user_id = profile.user_id;

drop function if exists public.get_leaderboard_settings();
create function public.get_leaderboard_settings()
returns table(is_opted_in boolean, display_name text)
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

  return query
  select
    coalesce(preference.is_opted_in, false),
    profile.display_name
  from (select v_user_id as user_id) caller
  left join public.leaderboard_preferences preference
    on preference.user_id = caller.user_id
  left join public.rider_profiles profile
    on profile.user_id = caller.user_id;
end;
$$;

drop function if exists public.set_leaderboard_consent(text, boolean);
create function public.set_leaderboard_consent(p_is_opted_in boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_display_name text;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.';
  end if;
  if p_is_opted_in is null then
    raise exception 'Participation consent is required.';
  end if;

  if p_is_opted_in then
    select profile.display_name
    into v_display_name
    from public.rider_profiles profile
    where profile.user_id = v_user_id;

    if v_display_name is null or char_length(btrim(v_display_name)) = 0 then
      raise exception 'Set your profile name before joining the leaderboard.';
    end if;
  end if;

  insert into public.leaderboard_preferences (user_id, is_opted_in, updated_at)
  values (v_user_id, p_is_opted_in, now())
  on conflict (user_id) do update
    set is_opted_in = excluded.is_opted_in,
        updated_at = now();

  if not p_is_opted_in then
    delete from public.weekly_cycling_leaderboard
    where user_id = v_user_id;
  end if;
end;
$$;

create or replace function public.record_my_leaderboard_ride(
  p_duration_seconds bigint,
  p_distance_meters double precision
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
  if p_duration_seconds is null
    or p_duration_seconds not between 0 and 172800
    or p_distance_meters is null
    or p_distance_meters < 0
    or p_distance_meters >= 1000000
    or p_distance_meters = 'NaN'::double precision
    or (p_duration_seconds = 0 and p_distance_meters = 0)
  then
    raise exception 'Ride records are outside leaderboard limits.';
  end if;
  update public.rider_profiles
  set longest_ride_duration_seconds = greatest(
        longest_ride_duration_seconds,
        p_duration_seconds
      ),
      longest_ride_distance_meters = greatest(
        longest_ride_distance_meters,
        p_distance_meters
      ),
      updated_at = now()
  where user_id = v_user_id
    and display_name is not null;

  if not found then
    raise exception 'Set your profile name before joining the leaderboard.';
  end if;
end;
$$;

drop function public.get_weekly_cycling_leaderboard(text);
create function public.get_weekly_cycling_leaderboard(p_category text)
returns table(
  place bigint,
  display_name text,
  score double precision,
  rider_level integer,
  rider_style text,
  experience bigint
)
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
  if p_category is null or p_category not in ('duration', 'distance') then
    raise exception 'Invalid leaderboard category.';
  end if;
  if not exists (
    select 1
    from public.leaderboard_preferences preference
    where preference.user_id = v_user_id
      and preference.is_opted_in
  ) then
    raise exception 'Leaderboard participation is not enabled.';
  end if;

  return query
  with personal_records as (
    select
      profile.user_id,
      profile.display_name,
      case
        when p_category = 'duration'
          then profile.longest_ride_duration_seconds::double precision
        else profile.longest_ride_distance_meters
      end as metric_score
    from public.rider_profiles profile
    join public.leaderboard_preferences preference
      on preference.user_id = profile.user_id
    where preference.is_opted_in
      and profile.display_name is not null
      and case
        when p_category = 'duration'
          then profile.longest_ride_duration_seconds > 0
        else profile.longest_ride_distance_meters > 0
      end
  ),
  ranked_records as (
    select
      rank() over (order by personal_records.metric_score desc) as metric_rank,
      personal_records.user_id,
      personal_records.display_name,
      personal_records.metric_score
    from personal_records
  )
  select
    ranked_records.metric_rank,
    ranked_records.display_name,
    ranked_records.metric_score,
    coalesce(profile.rider_level, 1),
    coalesce(profile.rider_style, 'explorer'),
    coalesce(profile.experience, 0)
  from ranked_records
  join public.rider_profiles profile
    on profile.user_id = ranked_records.user_id
  order by ranked_records.metric_score desc, ranked_records.display_name
  limit 50;
end;
$$;

drop function if exists public.submit_leaderboard_ride(uuid);

revoke all on function public.get_leaderboard_settings()
  from public, anon;
revoke all on function public.set_leaderboard_consent(boolean)
  from public, anon;
revoke all on function public.record_my_leaderboard_ride(bigint, double precision)
  from public, anon;
revoke all on function public.get_weekly_cycling_leaderboard(text)
  from public, anon;

grant execute on function public.get_leaderboard_settings()
  to authenticated;
grant execute on function public.set_leaderboard_consent(boolean)
  to authenticated;
grant execute on function public.record_my_leaderboard_ride(bigint, double precision)
  to authenticated;
grant execute on function public.get_weekly_cycling_leaderboard(text)
  to authenticated;
