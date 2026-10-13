import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/teams/data/cycling_team_repository.dart';
import 'package:senapath/features/teams/domain/cycling_team.dart';
import 'package:senapath/features/teams/presentation/cycling_team_cubit.dart';
import 'package:senapath/features/teams/presentation/cycling_team_screen.dart';

void main() {
  test('team dashboard aggregates shared sessions and groups by member', () {
    final dashboard = CyclingTeamDashboard(
      team: const CyclingTeam(
        id: 'team-1',
        name: 'Gowes Pagi',
        inviteCode: 'ABC123',
        role: 'manager',
        memberCount: 2,
      ),
      members: [
        CyclingTeamMember(
          userId: 'rider-1',
          displayName: 'Rider Satu',
          role: 'manager',
          joinedAt: DateTime.utc(2026, 10, 1),
        ),
        CyclingTeamMember(
          userId: 'rider-2',
          displayName: 'Rider Dua',
          role: 'member',
          joinedAt: DateTime.utc(2026, 10, 2),
        ),
      ],
      sharedSessions: [
        TeamRideSummary(
          userId: 'rider-1',
          sessionId: 'ride-1',
          startedAt: DateTime.utc(2026, 10, 1, 8),
          endedAt: DateTime.utc(2026, 10, 1, 9),
          durationSeconds: 3600,
          distanceMeters: 20000,
          sampleCount: 30,
          elevationGainMeters: 100,
          elevationSource: 'GPS',
        ),
        TeamRideSummary(
          userId: 'rider-2',
          sessionId: 'ride-2',
          startedAt: DateTime.utc(2026, 10, 2, 8),
          endedAt: DateTime.utc(2026, 10, 2, 10),
          durationSeconds: 7200,
          distanceMeters: 40000,
          sampleCount: 60,
          elevationGainMeters: null,
          elevationSource: 'GPS',
        ),
      ],
    );

    expect(dashboard.totalDistanceMeters, 60000);
    expect(dashboard.totalDurationSeconds, 10800);
    expect(dashboard.totalElevationGainMeters, 100);
    expect(dashboard.totalSampleCount, 90);
    expect(dashboard.sessionsFor('rider-1'), hasLength(1));
    expect(dashboard.sessionsFor('rider-2'), hasLength(1));
    expect(dashboard.sessionsFor('unknown'), isEmpty);
  });

  test('team manager can delete a team and refresh membership', () async {
    final repository = _DeleteTeamRepository();
    final cubit = CyclingTeamCubit(repository);
    addTearDown(cubit.close);

    await cubit.deleteTeam('team-1');

    expect(repository.deletedTeamId, 'team-1');
    expect(cubit.state.teams, isEmpty);
    expect(cubit.state.isSaving, isFalse);
    expect(cubit.state.message, 'Tim berhasil dihapus.');
  });

  testWidgets('team screen explains when online account setup is missing', (
    tester,
  ) async {
    final cubit = CyclingTeamCubit(_UnconfiguredTeamRepository());
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: cubit,
            child: const CyclingTeamScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Fitur tim memerlukan konfigurasi akun online.'),
      findsOneWidget,
    );
  });

  testWidgets('signed-in riders can join a team with an invite code', (
    tester,
  ) async {
    final cubit = CyclingTeamCubit(_AvailableTeamRepository());
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: cubit,
            child: const CyclingTeamScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gabung pakai kode'), findsOneWidget);
    expect(find.text('Buat tim'), findsOneWidget);
    expect(
      find.textContaining('Kamu belum tergabung dalam tim.'),
      findsOneWidget,
    );
  });
}

class _UnconfiguredTeamRepository implements CyclingTeamRepository {
  @override
  bool get isConfigured => false;

  @override
  bool get isSignedIn => false;

  @override
  String? get currentUserId => null;

  @override
  Future<List<CyclingTeam>> loadTeams() async => const [];

  @override
  Future<CyclingTeam> createTeam(String name, String displayName) =>
      throw UnimplementedError();

  @override
  Future<CyclingTeam> joinTeam(String inviteCode, String displayName) =>
      throw UnimplementedError();

  @override
  Future<CyclingTeamDashboard> loadDashboard(String teamId) =>
      throw UnimplementedError();

  @override
  Future<void> leaveTeam(String teamId) => throw UnimplementedError();

  @override
  Future<void> deleteTeam(String teamId) => throw UnimplementedError();

  @override
  Future<void> unshareSession(String teamId, String sessionId) =>
      throw UnimplementedError();

  @override
  Future<void> setMemberRole(String teamId, String userId, String role) =>
      throw UnimplementedError();
}

class _AvailableTeamRepository extends _UnconfiguredTeamRepository {
  @override
  bool get isConfigured => true;

  @override
  bool get isSignedIn => true;

  @override
  String? get currentUserId => 'rider-1';
}

class _DeleteTeamRepository extends _UnconfiguredTeamRepository {
  String? deletedTeamId;

  @override
  Future<void> deleteTeam(String teamId) async {
    deletedTeamId = teamId;
  }
}
