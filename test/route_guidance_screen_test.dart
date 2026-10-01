import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/routes/domain/saved_route.dart';
import 'package:senapath/features/routes/presentation/route_guidance_cubit.dart';
import 'package:senapath/features/routes/presentation/route_guidance_screen.dart';
import 'package:senapath/features/routes/presentation/routes_screen.dart';

void main() {
  testWidgets(
    'keeps the GPX route visible when location permission is denied',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RouteGuidanceScreen(
              route: _route(),
              positionSource: _DeniedPositionSource(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RouteMapPreview), findsOneWidget);
      expect(find.textContaining('izin lokasi'), findsWidgets);
      expect(
        find.textContaining('tidak memuat instruksi belokan'),
        findsOneWidget,
      );
    },
  );
}

RouteRecord _route() => RouteRecord(
  id: 'route-screen-test',
  name: 'Loop Selatan',
  source: 'GPX lokal',
  updatedAt: DateTime.utc(2026),
  availability: 'offline',
  points: const [
    RoutePoint(latitude: -6.2, longitude: 106.8, elevationMeters: 12),
    RoutePoint(latitude: -6.203, longitude: 106.803, elevationMeters: 35),
  ],
);

class _DeniedPositionSource implements RoutePositionSource {
  @override
  Future<bool> requestPermission() async => false;

  @override
  Stream<RoutePosition> watch() => const Stream.empty();
}
