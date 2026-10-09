insert into public.app_users (id, email, password_hash)
values
  ('10000000-0000-4000-8000-000000000001', 'demo.sprinter@example.invalid', null),
  ('10000000-0000-4000-8000-000000000002', 'demo.climber@example.invalid', null),
  ('10000000-0000-4000-8000-000000000003', 'demo.explorer@example.invalid', null),
  ('10000000-0000-4000-8000-000000000004', 'demo.ace@example.invalid', null),
  ('20000000-0000-4000-8000-000000000001', 'demo.road-sprinter@example.invalid', null),
  ('20000000-0000-4000-8000-000000000002', 'demo.road-climber@example.invalid', null),
  ('20000000-0000-4000-8000-000000000003', 'demo.road-explorer@example.invalid', null),
  ('20000000-0000-4000-8000-000000000004', 'demo.road-ace@example.invalid', null)
on conflict do nothing;

insert into public.cycling_teams (id, name, invite_code, created_by)
values
  (
    '30000000-0000-4000-8000-000000000001',
    'Garuda Sprint Collective',
    'A1000000000040008000000000000001',
    '10000000-0000-4000-8000-000000000001'
  ),
  (
    '30000000-0000-4000-8000-000000000002',
    'Jelajah Puncak Nusantara',
    'A2000000000040008000000000000002',
    '20000000-0000-4000-8000-000000000001'
  )
on conflict (id) do nothing;

insert into public.cycling_team_members (team_id, user_id, display_name, role)
values
  ('30000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'Aero', 'manager'),
  ('30000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000002', 'Tanjak', 'member'),
  ('30000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000003', 'Rimba', 'member'),
  ('30000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000004', 'All-rounder', 'member'),
  ('30000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-000000000001', 'Peloton', 'manager'),
  ('30000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-000000000002', 'Kawah', 'member'),
  ('30000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-000000000003', 'Penjelajah', 'member'),
  ('30000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-000000000004', 'Serbaguna', 'member')
on conflict (team_id, user_id) do nothing;

insert into public.rider_profiles (user_id, rider_style, rider_level, experience)
values
  ('10000000-0000-4000-8000-000000000001', 'sprinter', 12, 5680),
  ('10000000-0000-4000-8000-000000000002', 'climber', 9, 4210),
  ('10000000-0000-4000-8000-000000000003', 'explorer', 7, 3225),
  ('10000000-0000-4000-8000-000000000004', 'ace', 15, 7340),
  ('20000000-0000-4000-8000-000000000001', 'sprinter', 10, 4775),
  ('20000000-0000-4000-8000-000000000002', 'climber', 14, 6650),
  ('20000000-0000-4000-8000-000000000003', 'explorer', 8, 3660),
  ('20000000-0000-4000-8000-000000000004', 'ace', 18, 8520)
on conflict (user_id) do nothing;

insert into public.leaderboard_preferences (
  user_id, is_opted_in, public_alias
)
values
  ('10000000-0000-4000-8000-000000000001', true, 'Aero'),
  ('10000000-0000-4000-8000-000000000002', true, 'Tanjak'),
  ('10000000-0000-4000-8000-000000000003', true, 'Rimba'),
  ('10000000-0000-4000-8000-000000000004', true, 'AllRounder'),
  ('20000000-0000-4000-8000-000000000001', true, 'Peloton'),
  ('20000000-0000-4000-8000-000000000002', true, 'Kawah'),
  ('20000000-0000-4000-8000-000000000003', true, 'Penjelajah'),
  ('20000000-0000-4000-8000-000000000004', true, 'Serbaguna')
on conflict (user_id) do nothing;

insert into public.weekly_cycling_leaderboard (
  user_id, week_start, best_duration_seconds, best_distance_meters
)
select
  seeded.user_id,
  date_trunc('week', now() at time zone 'UTC')::date,
  seeded.best_duration_seconds,
  seeded.best_distance_meters
from (values
  ('10000000-0000-4000-8000-000000000001'::uuid, 54000::bigint, 62000::double precision),
  ('10000000-0000-4000-8000-000000000002'::uuid, 48600::bigint, 45500::double precision),
  ('10000000-0000-4000-8000-000000000003'::uuid, 39600::bigint, 38200::double precision),
  ('10000000-0000-4000-8000-000000000004'::uuid, 61200::bigint, 70400::double precision),
  ('20000000-0000-4000-8000-000000000001'::uuid, 50400::bigint, 58000::double precision),
  ('20000000-0000-4000-8000-000000000002'::uuid, 55800::bigint, 66200::double precision),
  ('20000000-0000-4000-8000-000000000003'::uuid, 43200::bigint, 42100::double precision),
  ('20000000-0000-4000-8000-000000000004'::uuid, 64800::bigint, 73500::double precision)
) as seeded(user_id, best_duration_seconds, best_distance_meters)
on conflict (user_id, week_start) do nothing;
