import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/ride_coach/data/ride_coach_gateway.dart';
import 'package:senapath/features/ride_coach/presentation/ride_coach_cubit.dart';
import 'package:senapath/features/ride_coach/presentation/ride_coach_session_panel.dart';
import 'package:senapath/features/session/domain/ride_session.dart';
import 'package:senapath/features/session/presentation/session_cubit.dart';

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

  testWidgets('shows coach recommendations inside an active session only', (
    tester,
  ) async {
    Future<void> pumpPanel(RideSessionState rideState) => tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RideCoachSessionPanel(sessionState: rideState),
            ),
          ),
        ),
      ),
    );

    await pumpPanel(
      RideSessionState(
        session: RideSessionSnapshot(
          id: 'ride-1',
          startedAt: DateTime.utc(2026, 10, 15),
          status: RideSessionStatus.recording,
          totalPausedMilliseconds: 0,
          distanceMeters: 500,
          currentSpeedMetersPerSecond: 3,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Pelatih AI'), findsOneWidget);
    expect(find.text('Izinkan pelatih untuk perjalanan ini'), findsOneWidget);

    await pumpPanel(const RideSessionState());
    await tester.pump();

    expect(find.text('Pelatih AI'), findsNothing);
  });

  test(
    'keeps a route-specific pre-ride briefing and reports failures',
    () async {
      gateway.briefings.add(
        Future.value('Simpan tenaga untuk tanjakan nanti.'),
      );
      await cubit.prepareRide(
        routeId: 'route-1',
        routeAndWeather: const {},
        consent: true,
      );

      expect(
        cubit.state.preRideBriefing,
        'Simpan tenaga untuk tanjakan nanti.',
      );
      expect(cubit.state.preRideRouteId, 'route-1');

      gateway.briefings.add(
        Future.error(StateError('Kuota AI harian tercapai.')),
      );
      await cubit.prepareRide(
        routeId: 'route-1',
        routeAndWeather: const {},
        consent: true,
      );
      expect(
        cubit.state.preRideBriefing,
        'Simpan tenaga untuk tanjakan nanti.',
      );
      expect(cubit.state.preRideError, 'Kuota AI harian tercapai.');
    },
  );
}

class _FakeRideCoachGateway implements RideCoachGateway {
  final List<Future<String>> responses = [];
  final List<Future<String>> briefings = [];

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

  @override
  Future<String> prepareRide({
    required Map<String, Object?> routeAndWeather,
    required bool consent,
  }) => briefings.removeAt(0);
}
