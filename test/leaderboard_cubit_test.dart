import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/leaderboard/data/leaderboard_gateway.dart';
import 'package:senapath/features/leaderboard/domain/leaderboard_models.dart';
import 'package:senapath/features/leaderboard/presentation/leaderboard_cubit.dart';

void main() {
  late _FakeLeaderboardGateway gateway;
  late LeaderboardCubit cubit;

  setUp(() {
    gateway = _FakeLeaderboardGateway();
    cubit = LeaderboardCubit(gateway);
  });

  tearDown(() async => cubit.close());

  test('loads public results only after opt-in and can opt out', () async {
    await cubit.load();
    expect(cubit.state.settings?.isOptedIn, isFalse);
    expect(gateway.loadEntriesCalls, 0);

    await cubit.saveConsent(alias: 'Rider 42', isOptedIn: true);
    expect(gateway.savedAlias, 'Rider 42');
    expect(cubit.state.settings?.isOptedIn, isTrue);
    expect(cubit.state.entries, hasLength(1));

    await cubit.submitSession('session-1');
    expect(gateway.submittedSessionId, 'session-1');
    expect(cubit.state.message, contains('minggu UTC'));

    await cubit.saveConsent(alias: '', isOptedIn: false);
    expect(cubit.state.settings?.isOptedIn, isFalse);
    expect(cubit.state.entries, isEmpty);
    expect(gateway.loadEntriesCalls, 2);
  });

  test('rejects invalid aliases without saving consent', () async {
    await cubit.load();
    await cubit.saveConsent(alias: 'ab!', isOptedIn: true);

    expect(cubit.state.error, contains('Alias harus'));
    expect(gateway.saveConsentCalls, 0);
  });

  test('requires opt-in before publishing a session', () async {
    await cubit.load();
    await cubit.submitSession('session-1');

    expect(cubit.state.error, contains('Aktifkan partisipasi'));
    expect(gateway.submittedSessionId, isNull);
  });

  test(
    'clears account-specific leaderboard state on account changes',
    () async {
      await cubit.load();
      await cubit.saveConsent(alias: 'Rider 42', isOptedIn: true);
      cubit.clearForAccountChange();

      expect(cubit.state.settings, isNull);
      expect(cubit.state.entries, isEmpty);
      expect(cubit.state.error, isNull);
    },
  );
}

class _FakeLeaderboardGateway implements LeaderboardGateway {
  bool optedIn = false;
  String? savedAlias;
  String? submittedSessionId;
  int loadEntriesCalls = 0;
  int saveConsentCalls = 0;

  @override
  bool get isConfigured => true;

  @override
  bool get isSignedIn => true;

  @override
  Future<List<LeaderboardEntry>> loadEntries(
    LeaderboardCategory category,
  ) async {
    loadEntriesCalls++;
    return const [LeaderboardEntry(rank: 1, alias: 'Rider 42', score: 7200)];
  }

  @override
  Future<LeaderboardSettings> loadSettings() async =>
      LeaderboardSettings(isOptedIn: optedIn, alias: savedAlias);

  @override
  Future<void> saveConsent({
    required String alias,
    required bool isOptedIn,
  }) async {
    saveConsentCalls++;
    optedIn = isOptedIn;
    savedAlias = isOptedIn ? alias : null;
  }

  @override
  Future<void> submitSession(String sessionId) async {
    submittedSessionId = sessionId;
  }
}
