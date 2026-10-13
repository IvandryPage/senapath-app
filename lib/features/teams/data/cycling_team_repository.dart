import 'package:supabase_flutter/supabase_flutter.dart';

import '../../authentication/data/custom_auth_session_manager.dart';
import '../../gamification/domain/rider_progress.dart';
import '../domain/cycling_team.dart';

abstract interface class CyclingTeamRepository {
  bool get isConfigured;
  bool get isSignedIn;
  String? get currentUserId;

  Future<List<CyclingTeam>> loadTeams();
  Future<CyclingTeam> createTeam(String name, String displayName);
  Future<CyclingTeam> joinTeam(String inviteCode, String displayName);
  Future<CyclingTeamDashboard> loadDashboard(String teamId);
  Future<void> leaveTeam(String teamId);
  Future<void> unshareSession(String teamId, String sessionId);
  Future<void> setMemberRole(String teamId, String userId, String role);
}

class SupabaseCyclingTeamRepository implements CyclingTeamRepository {
  const SupabaseCyclingTeamRepository(this._client, this._sessionManager);

  final SupabaseClient? _client;
  final CustomAuthSessionManager _sessionManager;

  @override
  bool get isConfigured => _client != null;

  @override
  bool get isSignedIn => _sessionManager.currentUserId != null;

  @override
  String? get currentUserId => _sessionManager.currentUserId;

  Future<SupabaseClient> _requireClient() async {
    final client = _client;
    if (client == null) {
      throw StateError('Fitur tim memerlukan konfigurasi layanan akun.');
    }
    if (_sessionManager.currentUserId == null) {
      throw StateError('Masuk ke akun untuk menggunakan fitur tim.');
    }
    await _sessionManager.requireAccessToken();
    return client;
  }

  @override
  Future<List<CyclingTeam>> loadTeams() async {
    final client = await _requireClient();
    final userId = _sessionManager.currentUserId!;
    final membershipRows = await client
        .from('cycling_team_members')
        .select('team_id, role')
        .eq('user_id', userId);
    if (membershipRows.isEmpty) return const [];

    final teamIds = membershipRows
        .map((row) => row['team_id']! as String)
        .toList(growable: false);
    final teams = await client
        .from('cycling_teams')
        .select('id, name')
        .inFilter('id', teamIds);
    final memberRows = await client
        .from('cycling_team_members')
        .select('team_id')
        .inFilter('team_id', teamIds);
    final counts = <String, int>{};
    for (final row in memberRows) {
      final id = row['team_id']! as String;
      counts.update(id, (count) => count + 1, ifAbsent: () => 1);
    }
    final roles = {
      for (final row in membershipRows)
        row['team_id']! as String: row['role']! as String,
    };

    return [
      for (final row in teams)
        CyclingTeam(
          id: row['id']! as String,
          name: row['name']! as String,
          inviteCode: '',
          role: roles[row['id']! as String]!,
          memberCount: counts[row['id']! as String] ?? 0,
        ),
    ];
  }

  @override
  Future<CyclingTeam> createTeam(String name, String displayName) async {
    final client = await _requireClient();
    final rows = await client.rpc(
      'create_cycling_team',
      params: {'p_name': name, 'p_display_name': displayName},
    );
    final row = (rows as List).single as Map<String, dynamic>;
    final teams = await loadTeams();
    return teams.firstWhere((team) => team.id == row['team_id']);
  }

  @override
  Future<CyclingTeam> joinTeam(String inviteCode, String displayName) async {
    final client = await _requireClient();
    final rows = await client.rpc(
      'join_cycling_team',
      params: {'p_invite_code': inviteCode, 'p_display_name': displayName},
    );
    final row = (rows as List).single as Map<String, dynamic>;
    final teams = await loadTeams();
    return teams.firstWhere((team) => team.id == row['team_id']);
  }

  @override
  Future<CyclingTeamDashboard> loadDashboard(String teamId) async {
    final client = await _requireClient();
    final teamRows = await client
        .from('cycling_teams')
        .select('id, name')
        .eq('id', teamId)
        .limit(1);
    if (teamRows.isEmpty) {
      throw StateError('Tim tidak tersedia atau aksesnya sudah dicabut.');
    }
    final memberships = await client
        .from('cycling_team_members')
        .select('user_id, display_name, role, joined_at')
        .eq('team_id', teamId)
        .order('joined_at');
    final memberIds = memberships
        .map((row) => row['user_id']! as String)
        .toSet()
        .toList(growable: false);
    final profileRows = memberIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await client
              .from('rider_profiles')
              .select('user_id, rider_style, rider_level, experience')
              .inFilter('user_id', memberIds);
    final profilesByUserId = {
      for (final row in profileRows) row['user_id']! as String: row,
    };
    final shares = await client
        .from('team_shared_ride_summaries')
        .select('user_id, session_id, shared_at')
        .eq('team_id', teamId)
        .order('shared_at', ascending: false);
    final sessions = <TeamRideSummary>[];

    if (shares.isNotEmpty) {
      final userIds = shares
          .map((row) => row['user_id']! as String)
          .toSet()
          .toList(growable: false);
      final sessionIds = shares
          .map((row) => row['session_id']! as String)
          .toSet()
          .toList(growable: false);
      final rows = await client
          .from('ride_session_summaries')
          .select(
            'user_id, session_id, started_at, ended_at, duration_seconds, '
            'distance_meters, sample_count, elevation_gain_meters, '
            'elevation_source',
          )
          .inFilter('user_id', userIds)
          .inFilter('session_id', sessionIds)
          .order('started_at', ascending: false);
      final sharedKeys = {
        for (final share in shares)
          '${share['user_id']}:${share['session_id']}',
      };
      for (final row in rows) {
        if (!sharedKeys.contains('${row['user_id']}:${row['session_id']}')) {
          continue;
        }
        sessions.add(
          TeamRideSummary(
            userId: row['user_id']! as String,
            sessionId: row['session_id']! as String,
            startedAt: DateTime.parse(row['started_at']! as String).toUtc(),
            endedAt: DateTime.parse(row['ended_at']! as String).toUtc(),
            durationSeconds: row['duration_seconds']! as int,
            distanceMeters: (row['distance_meters']! as num).toDouble(),
            sampleCount: row['sample_count']! as int,
            elevationGainMeters: (row['elevation_gain_meters'] as num?)
                ?.toDouble(),
            elevationSource: row['elevation_source']! as String,
          ),
        );
      }
    }

    final ownMembership = memberships
        .where((row) => row['user_id'] == _sessionManager.currentUserId)
        .firstOrNull;
    if (ownMembership == null) {
      throw StateError('Kamu bukan anggota tim ini atau akses sudah dicabut.');
    }
    final team = teamRows.single;
    final role = ownMembership['role']! as String;
    final inviteCode = role == 'manager'
        ? await client.rpc(
            'get_cycling_team_invite_code',
            params: {'p_team_id': teamId},
          )
        : '';
    return CyclingTeamDashboard(
      team: CyclingTeam(
        id: team['id']! as String,
        name: team['name']! as String,
        inviteCode: inviteCode as String,
        role: role,
        memberCount: memberships.length,
      ),
      members: [
        for (final row in memberships)
          CyclingTeamMember(
            userId: row['user_id']! as String,
            displayName: row['display_name']! as String,
            role: row['role']! as String,
            joinedAt: DateTime.parse(row['joined_at']! as String).toUtc(),
            riderStyle: RiderStyle.fromName(
              profilesByUserId[row['user_id']! as String]?['rider_style'],
            ),
            riderLevel:
                (profilesByUserId[row['user_id']! as String]?['rider_level']
                        as num?)
                    ?.toInt() ??
                1,
            experience:
                (profilesByUserId[row['user_id']! as String]?['experience']
                        as num?)
                    ?.toInt() ??
                0,
          ),
      ],
      sharedSessions: sessions,
    );
  }

  @override
  Future<void> leaveTeam(String teamId) async {
    final client = await _requireClient();
    await client.rpc('leave_cycling_team', params: {'p_team_id': teamId});
  }

  @override
  Future<void> unshareSession(String teamId, String sessionId) async {
    final client = await _requireClient();
    await client
        .from('team_shared_ride_summaries')
        .delete()
        .eq('team_id', teamId)
        .eq('user_id', _sessionManager.currentUserId!)
        .eq('session_id', sessionId);
  }

  @override
  Future<void> setMemberRole(String teamId, String userId, String role) async {
    final client = await _requireClient();
    await client.rpc(
      'set_cycling_team_member_role',
      params: {'p_team_id': teamId, 'p_user_id': userId, 'p_role': role},
    );
  }
}
