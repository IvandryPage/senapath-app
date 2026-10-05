import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/core/storage/app_database.dart';
import 'package:senapath/core/units/unit_settings_cubit.dart';
import 'package:senapath/core/units/unit_settings_repository.dart';
import 'package:senapath/features/routes/domain/saved_route.dart';
import 'package:senapath/features/routes/presentation/route_guidance_cubit.dart';
import 'package:senapath/features/routes/presentation/route_guidance_screen.dart';
import 'package:senapath/features/routes/presentation/routes_screen.dart';

void main() {
  testWidgets(
    'keeps the GPX route visible when location permission is denied',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final unitCubit = UnitSettingsCubit(UnitSettingsRepository(database));
      await unitCubit.load();
      addTearDown(unitCubit.close);
      addTearDown(database.close);

      await tester.pumpWidget(
        BlocProvider.value(
          value: unitCubit,
          child: MaterialApp(
            home: Scaffold(
              body: RouteGuidanceScreen(
                route: _route(),
                positionSource: _DeniedPositionSource(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RouteMapPreview), findsOneWidget);
      expect(
        tester.getSize(find.byType(RouteMapPreview)).height,
        greaterThan(220),
      );
      expect(find.textContaining('izin lokasi'), findsWidgets);
      expect(
        find.textContaining('tidak memuat instruksi belokan'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Peta OpenStreetMap dengan jejak GPX lokal 2 titik',
        ),
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
