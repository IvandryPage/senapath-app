import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/core/storage/app_database.dart';
import 'package:senapath/features/assistant/data/ai_chat_gateway.dart';
import 'package:senapath/features/assistant/domain/ai_chat_message.dart';
import 'package:senapath/features/logistics/data/logistics_repository.dart';
import 'package:senapath/features/logistics/domain/logistics_models.dart';
import 'package:senapath/features/logistics/presentation/logistics_cubit.dart';
import 'package:senapath/features/logistics/presentation/resupply_cache_sheet.dart';
import 'package:senapath/features/routes/domain/saved_route.dart';
import 'package:senapath/features/routes/presentation/explore_map.dart';

void main() {
  testWidgets('GPX checkpoint map markers handle taps', (tester) async {
    RouteCheckpoint? selectedCheckpoint;
    final route = RouteRecord(
      id: 'gpx-route',
      name: 'Touring Malaysia',
      source: 'GPX lokal',
      updatedAt: DateTime.utc(2026),
      availability: 'offline',
      points: const [
        RoutePoint(latitude: 3.139, longitude: 101.686, elevationMeters: 0),
        RoutePoint(latitude: 3.139, longitude: 101.696, elevationMeters: 0),
      ],
      checkpoints: const [
        RouteCheckpoint(name: 'Pos Air', latitude: 3.139, longitude: 101.691),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExploreMap(
            routes: [route],
            height: 500,
            showLocationButton: false,
            showEmptyMessage: false,
            onCheckpointTap: (route, checkpoint) {
              selectedCheckpoint = checkpoint;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.flag_circle));
    await tester.pump();

    expect(selectedCheckpoint?.name, 'Pos Air');
  });

  testWidgets('checkpoint sheet can be closed with its close button', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final cubit = LogisticsCubit(LogisticsRepository(database));
    await cubit.load();

    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  enableDrag: false,
                  showDragHandle: false,
                  builder: (_) => const ResupplyCacheSheet(
                    routeName: 'Touring Malaysia',
                    checkpoint: RouteCheckpoint(
                      name: 'Pos Air',
                      latitude: 3.139,
                      longitude: 101.6869,
                    ),
                  ),
                ),
                child: const Text('Buka checkpoint'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Buka checkpoint'));
    await tester.pumpAndSettle();
    expect(find.text('Pos Air'), findsOneWidget);

    await tester.tap(find.byTooltip('Tutup checkpoint'));
    await tester.pumpAndSettle();

    expect(find.text('Pos Air'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await cubit.close();
    await database.close();
  });

  testWidgets(
    'resupply items are customizable and estimates load on selection',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final gateway = _FakeAiChatGateway(
        '{"items":[{"id":"water","low":2,"high":4,"currency":"MYR"}]}',
      );
      final cubit = LogisticsCubit(
        LogisticsRepository(database),
        aiChatGateway: gateway,
      );
      await cubit.load();
      await cubit.updateRates(const {
        BudgetCurrency.idr: 17000,
        BudgetCurrency.usd: 1.1,
        BudgetCurrency.chf: 0.95,
        BudgetCurrency.myr: 4.5,
      });

      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: const MaterialApp(
            home: Scaffold(
              body: ResupplyCacheSheet(
                routeName: 'Touring Malaysia',
                checkpoint: RouteCheckpoint(
                  name: 'Pos Air',
                  latitude: 3.139,
                  longitude: 101.6869,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pos Air'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<BudgetCurrency>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('MYR').last);
      await tester.pumpAndSettle();
      expect(find.text('Air minum 1,5 L'), findsOneWidget);
      expect(find.text('Minuman elektrolit'), findsOneWidget);
      expect(find.text('Snack energi'), findsOneWidget);
      expect(find.text('Ban dalam'), findsOneWidget);

      await tester.ensureVisible(find.text('Tambah barang'));
      await tester.tap(find.text('Tambah barang'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Roti isi');
      await tester.tap(find.text('Tambah').last);
      await tester.pumpAndSettle();
      expect(find.text('Roti isi'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Hapus Roti isi'));
      await tester.tap(find.byTooltip('Hapus Roti isi'));
      await tester.pumpAndSettle();
      expect(find.text('Roti isi'), findsNothing);

      await tester.ensureVisible(find.text('Air minum 1,5 L'));
      await tester.tap(find.text('Air minum 1,5 L'));
      await tester.pumpAndSettle();
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(gateway.sentMessages, hasLength(1));
      expect(find.textContaining('MYR'), findsAtLeastNWidgets(1));
      expect(find.textContaining('2.00'), findsAtLeastNWidgets(1));
      expect(find.textContaining('IDR'), findsAtLeastNWidgets(1));
      expect(find.textContaining('7,556'), findsAtLeastNWidgets(1));
      expect(find.textContaining('non-real-time'), findsOneWidget);
      expect(gateway.sentContext['feature'], 'cycling-resupply-price-estimate');
      expect(gateway.sentMessages.single.content, contains('tidak diketahui'));
      expect(gateway.sentMessages.single.content, isNot(contains('3.139')));

      await tester.pumpWidget(const SizedBox());
      await cubit.close();
      await database.close();
    },
  );
}

class _FakeAiChatGateway implements AiChatGateway {
  _FakeAiChatGateway(this.reply);

  final String reply;
  late List<AiChatMessage> sentMessages;
  late Map<String, Object?> sentContext;

  @override
  bool get isConfigured => true;

  @override
  Future<String> send({
    required List<AiChatMessage> messages,
    required Map<String, Object?> context,
  }) async {
    sentMessages = messages;
    sentContext = context;
    return reply;
  }
}
