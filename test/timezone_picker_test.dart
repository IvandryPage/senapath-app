import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/core/storage/app_database.dart';
import 'package:senapath/features/logistics/data/logistics_repository.dart';
import 'package:senapath/features/logistics/presentation/logistics_cubit.dart';
import 'package:senapath/features/logistics/presentation/logistics_screen.dart';

void main() {
  testWidgets('searches and selects source and destination IANA zones', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final cubit = LogisticsCubit(LogisticsRepository(database));
    await cubit.load();
    addTearDown(cubit.close);
    addTearDown(database.close);

    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: const MaterialApp(home: Scaffold(body: LogisticsScreen())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Waktu dunia'));
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Zona waktu sumber'),
      250,
      scrollable: scrollable,
    );
    await tester.tap(find.text('Zona waktu sumber'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'New York');
    await tester.pumpAndSettle();
    await tester.tap(find.text('America/New York'));
    await tester.pumpAndSettle();

    expect(find.textContaining('America/New York'), findsWidgets);

    await tester.ensureVisible(find.text('Tambah zona'));
    await tester.tap(find.text('Tambah zona'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Tokyo');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Asia/Tokyo').first);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.widgetWithText(ListTile, 'Asia/Tokyo'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Asia/Tokyo'), findsWidgets);
  });
}
