import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/gamification/domain/rider_progress.dart';
import 'package:senapath/features/teams/domain/cycling_team.dart';

void main() {
  group('CyclingTeam', () {
    test('reports manager role', () {
      const team = CyclingTeam(
        id: 't1',
        name: 'Peloton',
        inviteCode: 'ABC123',
        role: 'manager',
        memberCount: 5,
      );
      expect(team.isManager, isTrue);

      const member = CyclingTeam(
        id: 't1',
        name: 'Peloton',
        inviteCode: 'ABC123',
        role: 'member',
        memberCount: 5,
      );
      expect(member.isManager, isFalse);
    });
  });

  group('CyclingTeamMember', () {
    test('defaults to an explorer at level one', () {
      final rider = CyclingTeamMember(
        userId: 'u1',
        displayName: 'Budi',
        role: 'member',
        joinedAt: DateTime.utc(2026),
      );
      expect(rider.riderStyle, RiderStyle.explorer);
      expect(rider.riderLevel, 1);
      expect(rider.experience, 0);
      expect(rider.isManager, isFalse);
    });

    test('keeps provided gamification values', () {
      final rider = CyclingTeamMember(
        userId: 'u2',
        displayName: 'Sari',
        role: 'manager',
        joinedAt: DateTime.utc(2026),
        riderStyle: RiderStyle.climber,
        riderLevel: 7,
        experience: 900,
      );
      expect(rider.riderStyle, RiderStyle.climber);
      expect(rider.riderLevel, 7);
      expect(rider.experience, 900);
      expect(rider.isManager, isTrue);
    });
  });

  group('CyclingTeamDashboard', () {
    final dashboard = CyclingTeamDashboard(
      team: const CyclingTeam(
        id: 't1',
        name: 'Peloton',
        inviteCode: 'CODE',
        role: 'manager',
        memberCount: 2,
      ),
      members: const [],
      sharedSessions: [
        TeamRideSummary(
          userId: 'u1',
          sessionId: 's1',
          startedAt: DateTime.utc(2026, 1, 5),
          endedAt: DateTime.utc(2026, 1, 5, 1),
          durationSeconds: 3600,
          distanceMeters: 20000,
          sampleCount: 120,
          elevationGainMeters: 300,
          elevationSource: 'gps',
        ),
        TeamRideSummary(
          userId: 'u2',
          sessionId: 's2',
          startedAt: DateTime.utc(2026, 1, 6),
          endedAt: DateTime.utc(2026, 1, 6, 1),
          durationSeconds: 1800,
          distanceMeters: 10000,
          sampleCount: 60,
          elevationGainMeters: null,
          elevationSource: 'none',
        ),
      ],
    );

    test('aggregates shared ride totals', () {
      expect(dashboard.totalDistanceMeters, 30000);
      expect(dashboard.totalDurationSeconds, 5400);
      expect(dashboard.totalElevationGainMeters, 300);
      expect(dashboard.totalSampleCount, 180);
    });

    test('filters sessions per member', () {
      expect(dashboard.sessionsFor('u1'), hasLength(1));
      expect(dashboard.sessionsFor('u1').single.sessionId, 's1');
      expect(dashboard.sessionsFor('missing'), isEmpty);
    });
  });
}
