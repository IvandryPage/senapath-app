-- Anchor referensi on-chain untuk ledger bukti perjalanan.
-- Hanya head hash + jumlah blok yang ditulis ke blockchain publik oleh relayer
-- server-side; tidak ada GPS, nama, email, maupun user id di transaksi.
create table public.ride_proof_chain_anchors (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.app_users(id) on delete cascade,
  block_count bigint not null check (block_count > 0),
  head_hash text not null check (head_hash ~ '^[0-9a-f]{64}$'),
  chain_id bigint not null check (chain_id > 0),
  tx_hash text check (tx_hash ~ '^0x[0-9a-f]{64}$'),
  status text not null default 'pending'
    check (status in ('pending', 'submitted', 'confirmed', 'failed')),
  block_number bigint check (block_number >= 0),
  error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index ride_proof_chain_anchors_tx_key
  on public.ride_proof_chain_anchors (chain_id, tx_hash)
  where tx_hash is not null;
create index ride_proof_chain_anchors_user_idx
  on public.ride_proof_chain_anchors (user_id, created_at desc);

alter table public.ride_proof_chain_anchors enable row level security;
revoke all on public.ride_proof_chain_anchors from public, anon, authenticated;
grant select on public.ride_proof_chain_anchors to authenticated;
grant select, insert, update on public.ride_proof_chain_anchors to service_role;

create policy "Riders can read own chain anchors"
  on public.ride_proof_chain_anchors for select to authenticated
  using (user_id = (select auth.uid()));

-- Memesan satu slot anchor untuk head cloud saat ini. Idempotent: bila head yang
-- sama sudah punya transaksi pada chain ini, baris lama dikembalikan (reused).
create or replace function public.reserve_ride_proof_anchor(
  p_user_id uuid,
  p_chain_id bigint,
  p_min_interval interval default interval '10 minutes'
)
returns table(
  anchor_id uuid,
  block_count bigint,
  head_hash text,
  tx_hash text,
  reused boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count bigint;
  v_head text;
  v_existing public.ride_proof_chain_anchors%rowtype;
  v_id uuid;
begin
  if p_user_id is null or not exists (
    select 1 from public.app_users account where account.id = p_user_id
  ) then
    raise exception 'UNKNOWN_OWNER';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('anchor:' || p_user_id::text, 0)
  );

  select head.block_count, head.latest_hash into v_count, v_head
  from public.ride_proof_cloud_heads head
  where head.user_id = p_user_id;
  if v_count is null or v_count < 1 then
    raise exception 'NO_PROOFS';
  end if;

  -- Reservasi yang macet (tanpa tx) dianggap gagal agar tidak memblokir.
  update public.ride_proof_chain_anchors anchor
  set status = 'failed', error = 'Reservasi kedaluwarsa.', updated_at = now()
  where anchor.user_id = p_user_id
    and anchor.status = 'pending'
    and anchor.created_at < now() - interval '2 minutes';

  select * into v_existing
  from public.ride_proof_chain_anchors anchor
  where anchor.user_id = p_user_id
    and anchor.chain_id = p_chain_id
    and anchor.head_hash = v_head
    and anchor.status in ('pending', 'submitted', 'confirmed')
  order by anchor.created_at desc
  limit 1;
  if found then
    return query select v_existing.id, v_existing.block_count,
      v_existing.head_hash, v_existing.tx_hash, true;
    return;
  end if;

  if exists (
    select 1 from public.ride_proof_chain_anchors anchor
    where anchor.user_id = p_user_id
      and anchor.status <> 'failed'
      and anchor.created_at > now() - p_min_interval
  ) then
    raise exception 'RATE_LIMITED';
  end if;

  insert into public.ride_proof_chain_anchors (
    user_id, block_count, head_hash, chain_id
  )
  values (p_user_id, v_count, v_head, p_chain_id)
  returning id into v_id;

  return query select v_id, v_count, v_head, null::text, false;
end;
$$;

revoke all on function public.reserve_ride_proof_anchor(uuid, bigint, interval)
  from public, anon, authenticated;
grant execute on function public.reserve_ride_proof_anchor(uuid, bigint, interval)
  to service_role;
