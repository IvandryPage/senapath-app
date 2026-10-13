create or replace function public.set_leaderboard_consent(
  p_is_opted_in boolean
)
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
end;
$$;

drop table if exists public.weekly_cycling_leaderboard;
