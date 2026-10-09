create or replace function public.join_cycling_team(
  p_invite_code text,
  p_display_name text
)
returns table(team_id uuid, team_name text, invite_code text, member_role text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_team public.cycling_teams%rowtype;
  v_display_name text := btrim(p_display_name);
  v_member_count integer;
begin
  if v_user_id is null then
    raise exception 'Sign in is required.';
  end if;
  if char_length(v_display_name) not between 1 and 60 then
    raise exception 'Display name must contain 1 to 60 characters.';
  end if;

  select * into v_team
  from public.cycling_teams team
  where team.invite_code = upper(btrim(p_invite_code))
  for update;
  if not found then
    raise exception 'Team invitation code is invalid.';
  end if;

  select count(*) into v_member_count
  from public.cycling_team_members membership
  where membership.team_id = v_team.id;
  if v_member_count >= 50 then
    raise exception 'This team has reached the 50-member limit.';
  end if;

  insert into public.cycling_team_members(team_id, user_id, display_name, role)
  values (v_team.id, v_user_id, v_display_name, 'member')
  on conflict on constraint cycling_team_members_pkey do nothing;

  if not found then
    raise exception 'You are already a member of this team.';
  end if;

  return query
  select v_team.id, v_team.name, ''::text, 'member'::text;
end;
$$;
