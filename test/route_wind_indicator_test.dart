import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/routes/domain/route_wind.dart';
import 'package:senapath/features/routes/presentation/route_wind_indicator.dart';

void main() {
  testWidgets('shows a translucent direction arrow without wind speed', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RouteWindIndicator(
              wind: RouteWindObservation(
                directionFromDegrees: 180,
                observedAt: DateTime.utc(2026, 10, 13),
              ),
              routeHeadingDegrees: 0,
              onPressed: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.navigation_outlined), findsOneWidget);
    expect(find.textContaining('m/s'), findsNothing);
    expect(find.textContaining('km/j'), findsNothing);
    expect(
      find.bySemanticsLabel('angin dari belakang relatif arah rute'),
      findsOneWidget,
    );
  });
}
