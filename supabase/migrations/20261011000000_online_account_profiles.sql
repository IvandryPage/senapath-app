alter table public.rider_profiles
  add column display_name text
  check (
    display_name is null
    or char_length(btrim(display_name)) between 1 and 60
  );

update public.rider_profiles profile
set display_name = (
  select membership.display_name
  from public.cycling_team_members membership
  where membership.user_id = profile.user_id
  order by membership.joined_at desc, membership.team_id
  limit 1
)
where profile.display_name is null
  and exists (
    select 1
    from public.cycling_team_members membership
    where membership.user_id = profile.user_id
  );

insert into public.rider_profiles (user_id, display_name)
select distinct on (membership.user_id)
  membership.user_id,
  membership.display_name
from public.cycling_team_members membership
left join public.rider_profiles profile
  on profile.user_id = membership.user_id
where profile.user_id is null
order by membership.user_id, membership.joined_at desc, membership.team_id;

create or replace function public.set_my_account_profile(
  p_display_name text,
  p_rider_style text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_display_name text := btrim(p_display_name);
begin
  if v_user_id is null then
    raise exception 'Authentication is required.';
  end if;
  if v_display_name is null
    or char_length(v_display_name) not between 1 and 60
  then
    raise exception 'Display name must contain 1 to 60 characters.';
  end if;
  if p_rider_style is null
    or p_rider_style not in ('sprinter', 'climber', 'explorer', 'ace')
  then
    raise exception 'Invalid cyclist type.';
  end if;

  insert into public.rider_profiles (
    user_id, display_name, rider_style, updated_at
  )
  values (v_user_id, v_display_name, p_rider_style, now())
  on conflict (user_id) do update
    set display_name = excluded.display_name,
        rider_style = excluded.rider_style,
        updated_at = now();

  update public.cycling_team_members
  set display_name = v_display_name
  where user_id = v_user_id;
end;
$$;

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
    set rider_level = excluded.rider_level,
        experience = excluded.experience,
        updated_at = now();
end;
$$;

revoke all on function public.set_my_account_profile(text, text)
  from public, anon;
grant execute on function public.set_my_account_profile(text, text)
  to authenticated;
