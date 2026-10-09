create table public.ride_proof_cloud_heads (
  user_id uuid primary key references public.app_users(id) on delete cascade,
  block_count bigint not null default 0 check (block_count >= 0),
  latest_hash text not null
    default '0000000000000000000000000000000000000000000000000000000000000000'
    check (latest_hash ~ '^[0-9a-f]{64}$'),
  updated_at timestamptz not null default now()
);

create table public.ride_proof_cloud_blocks (
  user_id uuid not null references public.app_users(id) on delete cascade,
  block_index bigint not null check (block_index >= 0),
  session_id uuid not null,
  created_at timestamptz not null,
  distance_meters double precision not null
    check (distance_meters >= 0 and distance_meters < 1000000),
  duration_seconds bigint not null
    check (duration_seconds >= 0 and duration_seconds <= 172800),
  previous_hash text not null check (previous_hash ~ '^[0-9a-f]{64}$'),
  hash text not null check (hash ~ '^[0-9a-f]{64}$'),
  synced_at timestamptz not null default now(),
  primary key (user_id, block_index),
  unique (user_id, session_id)
);

alter table public.ride_proof_cloud_heads enable row level security;
alter table public.ride_proof_cloud_blocks enable row level security;
revoke all on public.ride_proof_cloud_heads,
  public.ride_proof_cloud_blocks from public, anon, authenticated;
grant select on public.ride_proof_cloud_heads,
  public.ride_proof_cloud_blocks to authenticated;

create policy "Riders can read own cloud proof chain"
  on public.ride_proof_cloud_heads for select to authenticated
  using (user_id = (select auth.uid()));
create policy "Riders can read own cloud proof blocks"
  on public.ride_proof_cloud_blocks for select to authenticated
  using (user_id = (select auth.uid()));

create or replace function public.append_my_ride_proof_blocks(
  p_user_id uuid,
  p_blocks jsonb
)
returns table(
  block_count bigint,
  latest_hash text,
  previous_head text,
  newly_added integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item jsonb;
  v_user_id uuid := p_user_id;
  v_expected_index bigint;
  v_previous_hash text;
  v_previous_head text;
  v_index bigint;
  v_session_id uuid;
  v_created_at timestamptz;
  v_distance double precision;
  v_duration bigint;
  v_block_previous text;
  v_hash text;
  v_existing_hash text;
  v_added integer := 0;
begin
  if v_user_id is null or not exists (
    select 1 from public.app_users account where account.id = v_user_id
  ) then
    raise exception 'Unknown proof owner.';
  end if;
  if jsonb_typeof(p_blocks) <> 'array'
    or jsonb_array_length(p_blocks) > 2000
  then
    raise exception 'Proof blocks must be an array of at most 2000 items.';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_user_id::text, 0)
  );

  insert into public.ride_proof_cloud_heads(user_id)
  values (v_user_id)
  on conflict (user_id) do nothing;

  select head.block_count, head.latest_hash
    into v_expected_index, v_previous_hash
  from public.ride_proof_cloud_heads head
  where head.user_id = v_user_id
  for update;
  v_previous_head := v_previous_hash;

  for v_item in select value from jsonb_array_elements(p_blocks)
  loop
    if jsonb_typeof(v_item) <> 'object'
      or (select count(*) from jsonb_object_keys(v_item)) <> 7
      or not (v_item ?& array[
        'index', 'sessionId', 'createdAt', 'distanceMeters',
        'durationSeconds', 'previousHash', 'hash'
      ])
    then
      raise exception 'Invalid proof block shape.';
    end if;

    v_index := (v_item ->> 'index')::bigint;
    v_session_id := (v_item ->> 'sessionId')::uuid;
    v_created_at := (v_item ->> 'createdAt')::timestamptz;
    v_distance := (v_item ->> 'distanceMeters')::double precision;
    v_duration := (v_item ->> 'durationSeconds')::bigint;
    v_block_previous := v_item ->> 'previousHash';
    v_hash := v_item ->> 'hash';

    if v_index is null
      or v_session_id is null
      or v_created_at is null
      or v_distance is null
      or v_distance < 0 or v_distance >= 1000000
      or v_duration is null or v_duration < 0 or v_duration > 172800
      or v_block_previous !~ '^[0-9a-f]{64}$'
      or v_hash !~ '^[0-9a-f]{64}$'
    then
      raise exception 'Invalid proof block data.';
    end if;

    select block.hash into v_existing_hash
    from public.ride_proof_cloud_blocks block
    where block.user_id = v_user_id
      and block.session_id = v_session_id;
    if found then
      if v_existing_hash <> v_hash then
        raise exception 'A synced session proof cannot be replaced.';
      end if;
      continue;
    end if;

    if v_index <> v_expected_index or v_block_previous <> v_previous_hash then
      raise exception 'Proof chain does not continue the current cloud head.';
    end if;

    insert into public.ride_proof_cloud_blocks (
      user_id, block_index, session_id, created_at,
      distance_meters, duration_seconds, previous_hash, hash
    )
    values (
      v_user_id, v_index, v_session_id, v_created_at,
      v_distance, v_duration, v_block_previous, v_hash
    );
    v_expected_index := v_expected_index + 1;
    v_previous_hash := v_hash;
    v_added := v_added + 1;
  end loop;

  update public.ride_proof_cloud_heads head
  set block_count = v_expected_index,
      latest_hash = v_previous_hash,
      updated_at = now()
  where head.user_id = v_user_id;

  return query
  select v_expected_index, v_previous_hash, v_previous_head, v_added;
end;
$$;

revoke all on function public.append_my_ride_proof_blocks(uuid, jsonb)
  from public, anon, authenticated;
grant execute on function public.append_my_ride_proof_blocks(uuid, jsonb)
  to service_role;
