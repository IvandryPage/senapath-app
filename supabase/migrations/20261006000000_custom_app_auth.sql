create table if not exists public.app_users (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  password_hash text,
  google_subject text,
  email_verified boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint app_users_email_normalized check (email = lower(btrim(email)))
);

create unique index if not exists app_users_email_unique
  on public.app_users (email);
create unique index if not exists app_users_google_subject_unique
  on public.app_users (google_subject)
  where google_subject is not null;

insert into public.app_users (id, email, email_verified, created_at, updated_at)
select distinct on (lower(btrim(users.email)))
  users.id,
  lower(btrim(users.email)),
  users.email_confirmed_at is not null,
  users.created_at,
  now()
from auth.users users
where users.email is not null and btrim(users.email) <> ''
order by lower(btrim(users.email)), users.created_at, users.id
on conflict (id) do nothing;

create table if not exists public.app_auth_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.app_users(id) on delete cascade,
  refresh_token_hash text not null unique,
  expires_at timestamptz not null,
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.app_auth_password_resets (
  token_hash text primary key,
  user_id uuid not null references public.app_users(id) on delete cascade,
  expires_at timestamptz not null,
  used_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.app_auth_email_verifications (
  token_hash text primary key,
  user_id uuid not null references public.app_users(id) on delete cascade,
  expires_at timestamptz not null,
  used_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.app_auth_rate_limits (
  bucket_key text primary key,
  window_started_at timestamptz not null,
  attempt_count integer not null check (attempt_count > 0)
);

alter table public.app_users enable row level security;
alter table public.app_auth_sessions enable row level security;
alter table public.app_auth_password_resets enable row level security;
alter table public.app_auth_email_verifications enable row level security;
alter table public.app_auth_rate_limits enable row level security;
revoke all on table public.app_users, public.app_auth_sessions,
  public.app_auth_password_resets, public.app_auth_email_verifications,
  public.app_auth_rate_limits
  from public, anon, authenticated;
grant all on table public.app_users, public.app_auth_sessions,
  public.app_auth_password_resets, public.app_auth_email_verifications,
  public.app_auth_rate_limits to service_role;

alter table public.ai_chat_daily_usage
  drop constraint if exists ai_chat_daily_usage_user_id_fkey;
alter table public.ai_chat_daily_usage
  add constraint ai_chat_daily_usage_user_id_fkey
  foreign key (user_id) references public.app_users(id) on delete cascade;

alter table public.user_feedback
  drop constraint if exists user_feedback_user_id_fkey;
alter table public.user_feedback
  add constraint user_feedback_user_id_fkey
  foreign key (user_id) references public.app_users(id) on delete cascade;

alter table public.ride_session_summaries
  drop constraint if exists ride_session_summaries_user_id_fkey;
alter table public.ride_session_summaries
  add constraint ride_session_summaries_user_id_fkey
  foreign key (user_id) references public.app_users(id) on delete cascade;

alter table public.leaderboard_preferences
  drop constraint if exists leaderboard_preferences_user_id_fkey;
alter table public.leaderboard_preferences
  add constraint leaderboard_preferences_user_id_fkey
  foreign key (user_id) references public.app_users(id) on delete cascade;

alter table public.weekly_cycling_leaderboard
  drop constraint if exists weekly_cycling_leaderboard_user_id_fkey;
alter table public.weekly_cycling_leaderboard
  add constraint weekly_cycling_leaderboard_user_id_fkey
  foreign key (user_id) references public.app_users(id) on delete cascade;

create or replace function public.rotate_app_auth_session(
  p_old_token_hash text,
  p_new_token_hash text,
  p_expires_at timestamptz
)
returns table(user_id uuid)
language sql
security definer
set search_path = ''
as $$
  update public.app_auth_sessions session
  set refresh_token_hash = p_new_token_hash,
      expires_at = p_expires_at
  where session.refresh_token_hash = p_old_token_hash
    and session.revoked_at is null
    and session.expires_at > now()
  returning session.user_id;
$$;

create or replace function public.revoke_app_auth_session(
  p_token_hash text
)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.app_auth_sessions session
  set revoked_at = coalesce(session.revoked_at, now())
  where session.refresh_token_hash = p_token_hash
    and session.revoked_at is null;
$$;

create or replace function public.complete_app_password_reset(
  p_token_hash text,
  p_password_hash text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  reset_user_id uuid;
begin
  update public.app_auth_password_resets reset
  set used_at = now()
  where reset.token_hash = p_token_hash
    and reset.used_at is null
    and reset.expires_at > now()
  returning reset.user_id into reset_user_id;

  if reset_user_id is null then
    return false;
  end if;

  update public.app_users
  set password_hash = p_password_hash,
      email_verified = true,
      updated_at = now()
  where id = reset_user_id;

  update public.app_auth_sessions
  set revoked_at = coalesce(revoked_at, now())
  where user_id = reset_user_id and revoked_at is null;

  return true;
end;
$$;

create or replace function public.verify_app_email(p_token_hash text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  verification_user_id uuid;
begin
  update public.app_auth_email_verifications verification
  set used_at = now()
  where verification.token_hash = p_token_hash
    and verification.used_at is null
    and verification.expires_at > now()
  returning verification.user_id into verification_user_id;

  if verification_user_id is null then
    return false;
  end if;

  update public.app_users
  set email_verified = true,
      updated_at = now()
  where id = verification_user_id;
  return true;
end;
$$;

create or replace function public.consume_app_auth_rate_limit(
  p_bucket_key text,
  p_limit integer,
  p_window_seconds integer
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  allowed boolean;
begin
  if p_bucket_key is null or p_limit < 1 or p_window_seconds < 1 then
    return false;
  end if;

  insert into public.app_auth_rate_limits (
    bucket_key,
    window_started_at,
    attempt_count
  )
  values (p_bucket_key, now(), 1)
  on conflict (bucket_key) do update
    set window_started_at = case
          when public.app_auth_rate_limits.window_started_at
            <= now() - make_interval(secs => p_window_seconds)
          then now()
          else public.app_auth_rate_limits.window_started_at
        end,
        attempt_count = case
          when public.app_auth_rate_limits.window_started_at
            <= now() - make_interval(secs => p_window_seconds)
          then 1
          else public.app_auth_rate_limits.attempt_count + 1
        end
  returning attempt_count <= p_limit into allowed;

  return allowed;
end;
$$;

revoke all on function public.rotate_app_auth_session(text, text, timestamptz)
  from public, anon, authenticated;
revoke all on function public.revoke_app_auth_session(text)
  from public, anon, authenticated;
revoke all on function public.complete_app_password_reset(text, text)
  from public, anon, authenticated;
revoke all on function public.verify_app_email(text)
  from public, anon, authenticated;
revoke all on function public.consume_app_auth_rate_limit(text, integer, integer)
  from public, anon, authenticated;
grant execute on function public.rotate_app_auth_session(text, text, timestamptz)
  to service_role;
grant execute on function public.revoke_app_auth_session(text)
  to service_role;
grant execute on function public.complete_app_password_reset(text, text)
  to service_role;
grant execute on function public.verify_app_email(text)
  to service_role;
grant execute on function public.consume_app_auth_rate_limit(text, integer, integer)
  to service_role;
