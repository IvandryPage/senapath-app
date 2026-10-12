import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/ride_coach/data/ride_coach_gateway.dart';
import 'package:senapath/features/ride_coach/presentation/ride_coach_cubit.dart';

void main() {
  late _FakeRideCoachGateway gateway;
  late RideCoachCubit cubit;

  setUp(() {
    gateway = _FakeRideCoachGateway();
    cubit = RideCoachCubit(gateway);
  });

  tearDown(() async {
    await cubit.close();
  });

  test(
    'keeps the current recommendation visible during a refresh failure',
    () async {
      gateway.responses.add(Future.value('Jaga pace tetap stabil.'));
      await cubit.recommend(rideContext: const {}, consent: true);

      final failedRefresh = Completer<String>();
      gateway.responses.add(failedRefresh.future);
      final refresh = cubit.recommend(rideContext: const {}, consent: true);

      expect(cubit.state.isLoading, isTrue);
      expect(cubit.state.recommendation, 'Jaga pace tetap stabil.');

      failedRefresh.completeError(StateError('Jaringan terputus.'));
      await refresh;

      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.recommendation, 'Jaga pace tetap stabil.');
      expect(cubit.state.error, 'Jaringan terputus.');
    },
  );

  test(
    'ignores an in-flight response after clearing the recommendation',
    () async {
      final pendingResponse = Completer<String>();
      gateway.responses.add(pendingResponse.future);
      final request = cubit.recommend(rideContext: const {}, consent: true);

      cubit.clearRecommendation();
      pendingResponse.complete('Saran dari sesi lama.');
      await request;

      expect(cubit.state.recommendation, isNull);
      expect(cubit.state.isLoading, isFalse);
    },
  );

  test('keeps consent for the same session and resets for a new session', () {
    cubit.setActiveSession('ride-1');
    expect(cubit.grantConsentForSession('ride-1'), isTrue);
    expect(cubit.hasConsentForSession('ride-1'), isTrue);

    cubit.setActiveSession('ride-1');
    expect(cubit.hasConsentForSession('ride-1'), isTrue);

    cubit.setActiveSession('ride-2');
    expect(cubit.hasConsentForSession('ride-1'), isFalse);
    expect(cubit.hasConsentForSession('ride-2'), isFalse);
  });
}

class _FakeRideCoachGateway implements RideCoachGateway {
  final List<Future<String>> responses = [];

  @override
  bool get isConfigured => true;

  @override
  bool get isSignedIn => true;

  @override
  Future<String> diagnoseConfiguration() async => 'OK';

  @override
  Future<String> recommend({
    required Map<String, Object?> rideContext,
    required bool consent,
  }) => responses.removeAt(0);
}
