create table if not exists public.user_feedback (
  idempotency_key text primary key
    check (idempotency_key ~ '^[A-Za-z0-9_-]{1,80}$'),
  user_id uuid not null references auth.users(id) on delete cascade,
  message text not null check (char_length(btrim(message)) between 1 and 4000),
  consented_at timestamptz not null default now(),
  submitted_at timestamptz not null default now()
);

alter table public.user_feedback enable row level security;
revoke all on table public.user_feedback from anon, authenticated;