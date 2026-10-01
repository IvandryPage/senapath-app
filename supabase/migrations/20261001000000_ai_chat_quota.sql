create table if not exists public.ai_chat_daily_usage (
  user_id uuid not null references auth.users(id) on delete cascade,
  usage_date date not null default (timezone('utc', now())::date),
  request_count integer not null default 0 check (request_count >= 0),
  primary key (user_id, usage_date)
);

alter table public.ai_chat_daily_usage enable row level security;
revoke all on table public.ai_chat_daily_usage from anon, authenticated;

create or replace function public.consume_ai_chat_quota(
  p_user_id uuid,
  p_daily_limit integer default 30
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  quota_available boolean;
begin
  if p_daily_limit < 1 then
    return false;
  end if;

  insert into public.ai_chat_daily_usage (user_id, usage_date, request_count)
  values (p_user_id, (now() at time zone 'utc')::date, 1)
  on conflict (user_id, usage_date)
  do update
    set request_count = public.ai_chat_daily_usage.request_count + 1
    where public.ai_chat_daily_usage.request_count < p_daily_limit
  returning true into quota_available;

  return coalesce(quota_available, false);
end;
$$;

revoke all on function public.consume_ai_chat_quota(uuid, integer)
  from public, anon, authenticated;
grant execute on function public.consume_ai_chat_quota(uuid, integer)
  to service_role;