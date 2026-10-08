drop function if exists public.verify_app_email(text);
drop table if exists public.app_auth_email_verifications;

alter table public.app_users
  drop column if exists email_verified;

drop index if exists public.app_users_email_unique;
alter table public.app_users
  add constraint app_users_email_key unique (email);

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
      updated_at = now()
  where id = reset_user_id;

  update public.app_auth_sessions
  set revoked_at = coalesce(revoked_at, now())
  where user_id = reset_user_id and revoked_at is null;

  return true;
end;
$$;

create or replace function public.register_app_user(
  p_email text,
  p_password_hash text,
  p_refresh_token_hash text,
  p_expires_at timestamptz
)
returns table(account_id uuid, account_email text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_email text;
begin
  insert into public.app_users (email, password_hash)
  values (p_email, p_password_hash)
  returning id, email into v_user_id, v_email;

  insert into public.app_auth_sessions (
    user_id,
    refresh_token_hash,
    expires_at
  )
  values (v_user_id, p_refresh_token_hash, p_expires_at);

  return query select v_user_id, v_email;
end;
$$;

revoke all on function public.register_app_user(text, text, text, timestamptz)
  from public, anon, authenticated;
grant execute on function public.register_app_user(text, text, text, timestamptz)
  to service_role;
