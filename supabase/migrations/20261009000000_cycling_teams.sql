create table public.cycling_teams (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 2 and 60),
  invite_code text not null unique
    check (invite_code ~ '^[A-F0-9]{32}$'),
  created_by uuid not null references public.app_users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table public.cycling_team_members (
  team_id uuid not null references public.cycling_teams(id) on delete cascade,
  user_id uuid not null references public.app_users(id) on delete cascade,
  display_name text not null check (char_length(btrim(display_name)) between 1 and 60),
  role text not null check (role in ('manager', 'member')),
  joined_at timestamptz not null default now(),
  primary key (team_id, user_id)
);

create table public.team_shared_ride_summaries (
  team_id uuid not null,
  user_id uuid not null,
  session_id uuid not null,
  shared_at timestamptz not null default now(),
  primary key (team_id, user_id, session_id),
  foreign key (team_id, user_id)
    references public.cycling_team_members(team_id, user_id) on delete cascade,
  foreign key (user_id, session_id)
    references public.ride_session_summaries(user_id, session_id) on delete cascade
);

create index cycling_team_members_user_id_idx
  on public.cycling_team_members(user_id);
create index team_shared_ride_summaries_team_id_idx
  on public.team_shared_ride_summaries(team_id, shared_at desc);

alter table public.cycling_teams enable row level security;
alter table public.cycling_team_members enable row level security;
alter table public.team_shared_ride_summaries enable row level security;

revoke all on public.cycling_teams, public.cycling_team_members,
  public.team_shared_ride_summaries from public, anon, authenticated;
grant select (id, name, created_by, created_at)
  on public.cycling_teams to authenticated;
grant select on public.cycling_team_members,
  public.team_shared_ride_summaries to authenticated;
grant insert, delete on public.team_shared_ride_summaries to authenticated;

create or replace function public.is_cycling_team_member(p_team_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.cycling_team_members membership
    where membership.team_id = p_team_id
      and membership.user_id = (select auth.uid())
  );
$$;

revoke all on function public.is_cycling_team_member(uuid)
  from public, anon;
grant execute on function public.is_cycling_team_member(uuid)
  to authenticated;

create policy "Team members can read their teams"
  on public.cycling_teams for select to authenticated
  using (public.is_cycling_team_member(id));

create policy "Team members can read their roster"
  on public.cycling_team_members for select to authenticated
  using (public.is_cycling_team_member(team_id));

create policy "Team members can read shared session links"
  on public.team_shared_ride_summaries for select to authenticated
  using (public.is_cycling_team_member(team_id));

create policy "Members can share their own summaries"
  on public.team_shared_ride_summaries for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and public.is_cycling_team_member(team_id)
  );

create policy "Members can unshare their own summaries"
  on public.team_shared_ride_summaries for delete to authenticated
  using (
    user_id = (select auth.uid())
    and public.is_cycling_team_member(team_id)
  );

create policy "Team members can read explicitly shared summaries"
  on public.ride_session_summaries for select to authenticated
  using (
    user_id = (select auth.uid())
    or exists (
      select 1
      from public.team_shared_ride_summaries shared
      where shared.user_id = ride_session_summaries.user_id
        and shared.session_id = ride_session_summaries.session_id
        and public.is_cycling_team_member(shared.team_id)
    )
  );

create or replace function public.create_cycling_team(
  p_name text,
  p_display_name text
)
returns table(team_id uuid, team_name text, invite_code text, member_role text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_team_id uuid;
  v_invite_code text;
  v_name text := btrim(p_name);
  v_display_name text := btrim(p_display_name);
begin
  if v_user_id is null then
    raise exception 'Sign in is required.';
  end if;
  if char_length(v_name) not between 2 and 60 then
    raise exception 'Team name must contain 2 to 60 characters.';
  end if;
  if char_length(v_display_name) not between 1 and 60 then
    raise exception 'Display name must contain 1 to 60 characters.';
  end if;

  loop
    v_invite_code := upper(replace(gen_random_uuid()::text, '-', ''));
    exit when not exists (
      select 1 from public.cycling_teams team
      where team.invite_code = v_invite_code
    );
  end loop;

  insert into public.cycling_teams(name, invite_code, created_by)
  values (v_name, v_invite_code, v_user_id)
  returning id into v_team_id;

  insert into public.cycling_team_members(team_id, user_id, display_name, role)
  values (v_team_id, v_user_id, v_display_name, 'manager');

  return query
  select v_team_id, v_name, v_invite_code, 'manager'::text;
end;
$$;

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
  on conflict (team_id, user_id) do nothing;

  if not found then
    raise exception 'You are already a member of this team.';
  end if;

  return query
  select v_team.id, v_team.name, ''::text, 'member'::text;
end;
$$;

create or replace function public.get_cycling_team_invite_code(p_team_id uuid)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_invite_code text;
begin
  select team.invite_code into v_invite_code
  from public.cycling_teams team
  join public.cycling_team_members membership
    on membership.team_id = team.id
  where team.id = p_team_id
    and membership.user_id = (select auth.uid())
    and membership.role = 'manager';
  if v_invite_code is null then
    raise exception 'Only team managers can view the invitation code.';
  end if;
  return v_invite_code;
end;
$$;

create or replace function public.leave_cycling_team(p_team_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_role text;
begin
  perform 1 from public.cycling_teams team
  where team.id = p_team_id
  for update;
  if not found then
    raise exception 'Team was not found.';
  end if;

  select membership.role into v_role
  from public.cycling_team_members membership
  where membership.team_id = p_team_id
    and membership.user_id = v_user_id;
  if v_role is null then
    raise exception 'You are not a member of this team.';
  end if;
  if v_role = 'manager' and not exists (
    select 1 from public.cycling_team_members other_manager
    where other_manager.team_id = p_team_id
      and other_manager.role = 'manager'
      and other_manager.user_id <> v_user_id
  ) then
    raise exception 'Assign another manager before leaving the team.';
  end if;

  delete from public.cycling_team_members membership
  where membership.team_id = p_team_id
    and membership.user_id = v_user_id;
end;
$$;

create or replace function public.set_cycling_team_member_role(
  p_team_id uuid,
  p_user_id uuid,
  p_role text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_target_role text;
begin
  if p_role is null or p_role not in ('manager', 'member') then
    raise exception 'Invalid team role.';
  end if;
  perform 1 from public.cycling_teams team
  where team.id = p_team_id
  for update;
  if not found then
    raise exception 'Team was not found.';
  end if;
  if not exists (
    select 1 from public.cycling_team_members manager
    where manager.team_id = p_team_id
      and manager.user_id = v_user_id
      and manager.role = 'manager'
  ) then
    raise exception 'Only a team manager can change member roles.';
  end if;
  if p_user_id = v_user_id then
    raise exception 'You cannot change your own team role.';
  end if;

  select member.role into v_target_role
  from public.cycling_team_members member
  where member.team_id = p_team_id
    and member.user_id = p_user_id
  for update;
  if v_target_role is null then
    raise exception 'Team member was not found.';
  end if;
  if v_target_role = 'manager'
     and p_role = 'member'
     and not exists (
       select 1 from public.cycling_team_members other_manager
       where other_manager.team_id = p_team_id
         and other_manager.role = 'manager'
         and other_manager.user_id not in (v_user_id, p_user_id)
     ) then
    raise exception 'A team must have at least one manager.';
  end if;

  update public.cycling_team_members member
  set role = p_role
  where member.team_id = p_team_id
    and member.user_id = p_user_id;
end;
$$;

revoke all on function public.create_cycling_team(text, text),
  public.join_cycling_team(text, text),
  public.get_cycling_team_invite_code(uuid),
  public.leave_cycling_team(uuid),
  public.set_cycling_team_member_role(uuid, uuid, text)
  from public, anon;
grant execute on function public.create_cycling_team(text, text),
  public.join_cycling_team(text, text),
  public.get_cycling_team_invite_code(uuid),
  public.leave_cycling_team(uuid),
  public.set_cycling_team_member_role(uuid, uuid, text)
  to authenticated;
