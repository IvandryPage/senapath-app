create table if not exists public.leaderboard_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  is_opted_in boolean not null default false,
  public_alias text,
  updated_at timestamptz not null default now(),
  check (
    (
      is_opted_in
      and public_alias is not null
      and char_length(public_alias) between 3 and 24
      and public_alias ~ '^[[:alnum:] _-]+$'
    )
    or (not is_opted_in and public_alias is null)
  )
);

create table if not exists public.weekly_cycling_leaderboard (
  user_id uuid not null references auth.users(id) on delete cascade,
  week_start date not null,
  best_duration_seconds bigint not null
    check (best_duration_seconds between 1 and 172800),
  best_distance_meters double precision not null
    check (
      best_distance_meters > 0
      and best_distance_meters < 1000000
    ),
  updated_at timestamptz not null default now(),
  primary key (user_id, week_start)
);

alter table public.leaderboard_preferences enable row level security;
alter table public.weekly_cycling_leaderboard enable row level security;

revoke all on table public.leaderboard_preferences
  from anon, authenticated;
revoke all on table public.weekly_cycling_leaderboard
  from anon, authenticated;

create or replace function public.get_leaderboard_settings()
returns table(is_opted_in boolean, public_alias text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Authentication is required.';
  end if;

  return query
  select
    coalesce(preference.is_opted_in, false),
    preference.public_alias
  from (select v_user_id as user_id) caller
  left join public.leaderboard_preferences preference
    on preference.user_id = caller.user_id;
end;
$$;

create or replace function public.set_leaderboard_consent(
  p_public_alias text,
  p_is_opted_in boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_alias text := nullif(btrim(p_public_alias), '');
begin
  if v_user_id is null then
    raise exception 'Authentication is required.';
  end if;
  if p_is_opted_in is null then
    raise exception 'Participation consent is required.';
  end if;

  if p_is_opted_in then
    if v_alias is null
      or char_length(v_alias) not between 3 and 24
      or v_alias !~ '^[[:alnum:] _-]+$'
    then
      raise exception 'Invalid public alias.';
    end if;

    insert into public.leaderboard_preferences (
      user_id,
      is_opted_in,
      public_alias,
      updated_at
    )
    values (v_user_id, true, v_alias, now())
    on conflict (user_id) do update
      set is_opted_in = excluded.is_opted_in,
          public_alias = excluded.public_alias,
          updated_at = excluded.updated_at;
  else
    insert into public.leaderboard_preferences (
      user_id,
      is_opted_in,
      public_alias,
      updated_at
    )
    values (v_user_id, false, null, now())
    on conflict (user_id) do update
      set is_opted_in = false,
          public_alias = null,
          updated_at = now();

    delete from public.weekly_cycling_leaderboard
    where user_id = v_user_id;
  end if;
end;
$$;

create or replace function public.submit_leaderboard_ride(
  p_session_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_summary public.ride_session_summaries%rowtype;
  v_week_start date;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.';
  end if;

  if not exists (
    select 1
    from public.leaderboard_preferences preference
    where preference.user_id = v_user_id
      and preference.is_opted_in
  ) then
    raise exception 'Leaderboard participation is not enabled.';
  end if;

  select summary.*
  into v_summary
  from public.ride_session_summaries summary
  where summary.user_id = v_user_id
    and summary.session_id = p_session_id
    and summary.ended_at is not null;

  if not found then
    raise exception 'Sync the completed session summary first.';
  end if;
  if v_summary.duration_seconds not between 1 and 172800
    or v_summary.distance_meters <= 0
    or v_summary.distance_meters >= 1000000
  then
    raise exception 'Session values are outside leaderboard limits.';
  end if;

  v_week_start := date_trunc(
    'week',
    v_summary.ended_at at time zone 'UTC'
  )::date;

  insert into public.weekly_cycling_leaderboard (
    user_id,
    week_start,
    best_duration_seconds,
    best_distance_meters,
    updated_at
  )
  values (
    v_user_id,
    v_week_start,
    v_summary.duration_seconds,
    v_summary.distance_meters,
    now()
  )
  on conflict (user_id, week_start) do update
    set best_duration_seconds = greatest(
          public.weekly_cycling_leaderboard.best_duration_seconds,
          excluded.best_duration_seconds
        ),
        best_distance_meters = greatest(
          public.weekly_cycling_leaderboard.best_distance_meters,
          excluded.best_distance_meters
        ),
        updated_at = now();
end;
$$;

create or replace function public.get_weekly_cycling_leaderboard(
  p_category text
)
returns table(place bigint, public_alias text, score double precision)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_week_start date := date_trunc(
    'week',
    now() at time zone 'UTC'
  )::date;
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
  with weekly_scores as (
    select
      preference.public_alias,
      case
        when p_category = 'duration'
          then leaderboard.best_duration_seconds::double precision
        else leaderboard.best_distance_meters
      end as metric_score
    from public.weekly_cycling_leaderboard leaderboard
    join public.leaderboard_preferences preference
      on preference.user_id = leaderboard.user_id
    where leaderboard.week_start = v_week_start
      and preference.is_opted_in
  ),
  ranked_scores as (
    select
      rank() over (order by weekly_scores.metric_score desc) as metric_rank,
      weekly_scores.public_alias as metric_alias,
      weekly_scores.metric_score
    from weekly_scores
  )
  select
    ranked_scores.metric_rank as place,
    ranked_scores.metric_alias,
    ranked_scores.metric_score
  from ranked_scores
  order by ranked_scores.metric_score desc, ranked_scores.metric_alias
  limit 50;
end;
$$;

revoke all on function public.get_leaderboard_settings() from public, anon;
revoke all on function public.set_leaderboard_consent(text, boolean)
  from public, anon;
revoke all on function public.submit_leaderboard_ride(uuid) from public, anon;
revoke all on function public.get_weekly_cycling_leaderboard(text)
  from public, anon;

grant execute on function public.get_leaderboard_settings()
  to authenticated;
grant execute on function public.set_leaderboard_consent(text, boolean)
  to authenticated;
grant execute on function public.submit_leaderboard_ride(uuid)
  to authenticated;
grant execute on function public.get_weekly_cycling_leaderboard(text)
  to authenticated;
