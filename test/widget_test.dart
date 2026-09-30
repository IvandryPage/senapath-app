import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/app/app.dart';
import 'package:senapath/core/widgets/feature_state_view.dart';

void main() {
  testWidgets('main shell navigates between core destinations', (tester) async {
    await tester.pumpWidget(const SenapathApp());
    await tester.pumpAndSettle();

    expect(find.text('Belum ada sesi'), findsOneWidget);

    await tester.tap(find.text('Rute').last);
    await tester.pumpAndSettle();
    expect(find.text('Belum ada rute tersimpan'), findsOneWidget);

    await tester.tap(find.text('Sesi').last);
    await tester.pumpAndSettle();
    expect(find.text('Perekaman belum dimulai'), findsOneWidget);

    await tester.tap(find.text('Profil').last);
    await tester.pumpAndSettle();
    expect(find.text('Profil belum tersedia'), findsOneWidget);
  });

  testWidgets('loading state is announced with progress', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: FeatureStateView.loading(message: 'Memuat rute')),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Memuat rute'), findsOneWidget);
  });

  testWidgets('error state exposes retry action', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FeatureStateView.error(
            message: 'Koneksi tidak tersedia',
            onAction: () => retried = true,
          ),
        ),
      ),
    );

    expect(find.text('Koneksi tidak tersedia'), findsOneWidget);
    await tester.tap(find.text('Coba lagi'));
    expect(retried, isTrue);
  });
}
