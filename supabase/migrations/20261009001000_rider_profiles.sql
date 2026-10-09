create table public.rider_profiles (
  user_id uuid primary key references public.app_users(id) on delete cascade,
  rider_style text not null default 'explorer'
    check (rider_style in ('sprinter', 'climber', 'explorer', 'ace')),
  rider_level integer not null default 1
    check (rider_level between 1 and 100000),
  experience bigint not null default 0
    check (experience between 0 and 1000000000),
  updated_at timestamptz not null default now()
);

alter table public.rider_profiles enable row level security;
revoke all on public.rider_profiles from public, anon, authenticated;
grant select on public.rider_profiles to authenticated;

create policy "Riders can read their own profile"
  on public.rider_profiles for select to authenticated
  using (user_id = (select auth.uid()));

create policy "Team members can read teammate rider profiles"
  on public.rider_profiles for select to authenticated
  using (
    exists (
      select 1
      from public.cycling_team_members self
      join public.cycling_team_members teammate
        on teammate.team_id = self.team_id
      where self.user_id = (select auth.uid())
        and teammate.user_id = rider_profiles.user_id
    )
  );

create or replace function public.set_my_rider_profile(
  p_rider_style text,
  p_rider_level integer,
  p_experience bigint
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
  then
    raise exception 'Invalid rider progress.';
  end if;

  insert into public.rider_profiles (
    user_id, rider_style, rider_level, experience, updated_at
  )
  values (
    v_user_id, p_rider_style, p_rider_level, p_experience, now()
  )
  on conflict (user_id) do update
    set rider_style = excluded.rider_style,
        rider_level = excluded.rider_level,
        experience = excluded.experience,
        updated_at = now();
end;
$$;

revoke all on function public.set_my_rider_profile(text, integer, bigint)
  from public, anon;
grant execute on function public.set_my_rider_profile(text, integer, bigint)
  to authenticated;

drop function public.get_weekly_cycling_leaderboard(text);

create function public.get_weekly_cycling_leaderboard(
  p_category text
)
returns table(
  place bigint,
  public_alias text,
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
  v_user_id uuid := auth.uid();
  v_week_start date := date_trunc('week', now() at time zone 'UTC')::date;
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
      leaderboard.user_id,
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
      weekly_scores.user_id as metric_user_id,
      weekly_scores.public_alias as metric_alias,
      weekly_scores.metric_score
    from weekly_scores
  )
  select
    ranked_scores.metric_rank,
    ranked_scores.metric_alias,
    ranked_scores.metric_score,
    coalesce(profile.rider_level, 1),
    coalesce(profile.rider_style, 'explorer'),
    coalesce(profile.experience, 0)
  from ranked_scores
  left join public.rider_profiles profile
    on profile.user_id = ranked_scores.metric_user_id
  order by ranked_scores.metric_score desc, ranked_scores.metric_alias
  limit 50;
end;
$$;

revoke all on function public.get_weekly_cycling_leaderboard(text)
  from public, anon;
grant execute on function public.get_weekly_cycling_leaderboard(text)
  to authenticated;
