import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/routes/domain/saved_route.dart';
import 'package:senapath/features/routes/presentation/route_guidance_cubit.dart';

void main() {
  test('tracks GPX progress and never moves progress backwards', () async {
    final source = _FakeRoutePositionSource();
    final cubit = RouteGuidanceCubit(source);
    addTearDown(cubit.close);
    await cubit.start(_route());

    final reachedMiddle = cubit.stream.firstWhere(
      (state) => state.currentPosition != null,
    );
    source.positions.add(
      const RoutePosition(latitude: 0, longitude: 0.001, accuracyMeters: 5),
    );
    final middle = await reachedMiddle;
    expect(middle.nearestRouteIndex, 1);
    expect(middle.distanceRemainingMeters, greaterThan(100));
    expect(middle.distanceRemainingMeters, lessThan(120));

    final stayedForward = cubit.stream.firstWhere(
      (state) => state.currentPosition?.longitude == 0,
    );
    source.positions.add(
      const RoutePosition(latitude: 0, longitude: 0, accuracyMeters: 5),
    );
    expect((await stayedForward).nearestRouteIndex, 1);
  });

  test('warns when an accurate GPS fix is off route', () async {
    final source = _FakeRoutePositionSource();
    final cubit = RouteGuidanceCubit(source);
    addTearDown(cubit.close);
    await cubit.start(_route());

    final offRoute = cubit.stream.firstWhere((state) => state.isOffRoute);
    source.positions.add(
      const RoutePosition(latitude: 0.001, longitude: 0.001, accuracyMeters: 5),
    );

    expect((await offRoute).distanceToRouteMeters, greaterThan(100));
  });

  test('does not report off-route while GPS accuracy is poor', () async {
    final source = _FakeRoutePositionSource();
    final cubit = RouteGuidanceCubit(source);
    addTearDown(cubit.close);
    await cubit.start(_route());

    final updated = cubit.stream.firstWhere(
      (state) => state.currentPosition != null,
    );
    source.positions.add(
      const RoutePosition(
        latitude: 0.001,
        longitude: 0.001,
        accuracyMeters: 95,
      ),
    );

    final state = await updated;
    expect(state.hasAccurateFix, isFalse);
    expect(state.isOffRoute, isFalse);
  });

  test('refuses to start when location permission is unavailable', () async {
    final source = _FakeRoutePositionSource(permissionGranted: false);
    final cubit = RouteGuidanceCubit(source);
    addTearDown(cubit.close);

    await cubit.start(_route());

    expect(cubit.state.isRunning, isFalse);
    expect(cubit.state.error, contains('izin lokasi'));
    expect(source.watchCalls, 0);
  });
}

RouteRecord _route() => RouteRecord(
  id: 'route-test',
  name: 'Loop Test',
  source: 'GPX lokal',
  updatedAt: DateTime.utc(2026),
  availability: 'offline',
  points: const [
    RoutePoint(latitude: 0, longitude: 0, elevationMeters: 0),
    RoutePoint(latitude: 0, longitude: 0.001, elevationMeters: 0),
    RoutePoint(latitude: 0, longitude: 0.002, elevationMeters: 0),
  ],
);

class _FakeRoutePositionSource implements RoutePositionSource {
  _FakeRoutePositionSource({this.permissionGranted = true});

  final bool permissionGranted;
  final positions = StreamController<RoutePosition>.broadcast();
  int watchCalls = 0;

  @override
  Future<bool> requestPermission() async => permissionGranted;

  @override
  Stream<RoutePosition> watch() {
    watchCalls++;
    return positions.stream;
  }
}
