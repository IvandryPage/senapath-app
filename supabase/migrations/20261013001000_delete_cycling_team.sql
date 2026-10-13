create or replace function public.delete_cycling_team(p_team_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'Sign in is required.';
  end if;

  perform 1
  from public.cycling_teams team
  where team.id = p_team_id
  for update;
  if not found then
    raise exception 'Team was not found.';
  end if;

  if not exists (
    select 1
    from public.cycling_team_members manager
    where manager.team_id = p_team_id
      and manager.user_id = (select auth.uid())
      and manager.role = 'manager'
  ) then
    raise exception 'Only a team manager can delete the team.';
  end if;

  delete from public.cycling_teams team
  where team.id = p_team_id;
end;
$$;

revoke all on function public.delete_cycling_team(uuid) from public, anon;
grant execute on function public.delete_cycling_team(uuid) to authenticated;
