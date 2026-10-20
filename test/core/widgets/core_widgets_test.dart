import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/core/widgets/active_navigation_branch.dart';
import 'package:senapath/core/widgets/feature_state_view.dart';
import 'package:senapath/core/widgets/press_scale.dart';

void main() {
  group('PressScale', () {
    testWidgets('invokes onTap when enabled', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PressScale(onTap: () => taps++, child: const Text('Go')),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Go'));
      expect(taps, 1);
    });

    testWidgets('ignores taps when disabled', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PressScale(
                enabled: false,
                onTap: () => taps++,
                child: const Text('Go'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Go'));
      expect(taps, 0);
    });

    testWidgets('scales down while pressed', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: PressScale(child: Text('Go')))),
        ),
      );

      final gesture = await tester.startGesture(tester.getCenter(find.text('Go')));
      await tester.pump(const Duration(milliseconds: 120));

      final scale = tester.widget<AnimatedScale>(
        find.descendant(
          of: find.byType(PressScale),
          matching: find.byType(AnimatedScale),
        ),
      );
      expect(scale.scale, closeTo(0.95, 0.001));

      await gesture.up();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester
            .widget<AnimatedScale>(
              find.descendant(
                of: find.byType(PressScale),
                matching: find.byType(AnimatedScale),
              ),
            )
            .scale,
        1,
      );
    });
  });

  group('ActiveNavigationBranch', () {
    testWidgets('exposes the active index to descendants', (tester) async {
      late BuildContext capturedContext;
      late ActiveNavigationBranch? branch;

      await tester.pumpWidget(
        MaterialApp(
          home: ActiveNavigationBranch(
            index: 2,
            child: Builder(
              builder: (context) {
                capturedContext = context;
                branch = ActiveNavigationBranch.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(branch, isNotNull);
      expect(branch!.index, 2);
      expect(branch!.isActive(2), isTrue);
      expect(branch!.isActive(1), isFalse);
      expect(ActiveNavigationBranch.of(capturedContext), isNotNull);
    });
  });

  group('FeatureStateView', () {
    testWidgets('loading shows a spinner and message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: FeatureStateView.loading(message: 'Memuat...')),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Memuat...'), findsOneWidget);
    });

    testWidgets('empty renders title, message and icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FeatureStateView.empty(
              title: 'Belum ada data',
              message: 'Mulailah merekam sesi.',
              icon: Icons.directions_bike,
            ),
          ),
        ),
      );

      expect(find.text('Belum ada data'), findsOneWidget);
      expect(find.text('Mulailah merekam sesi.'), findsOneWidget);
      expect(find.byIcon(Icons.directions_bike), findsOneWidget);
    });

    testWidgets('error action button fires the callback', (tester) async {
      var retried = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeatureStateView.error(
              message: 'Gagal memuat.',
              onAction: () => retried++,
            ),
          ),
        ),
      );

      expect(find.text('Terjadi kendala'), findsOneWidget);
      await tester.tap(find.text('Coba lagi'));
      expect(retried, 1);
    });
  });
}
