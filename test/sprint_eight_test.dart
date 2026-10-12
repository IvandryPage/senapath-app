import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:senapath/core/storage/app_database.dart';
import 'package:senapath/features/assistant/data/ai_chat_gateway.dart';
import 'package:senapath/features/assistant/domain/ai_chat_message.dart';
import 'package:senapath/features/logistics/data/logistics_repository.dart';
import 'package:senapath/features/logistics/data/exchange_rate_service.dart';
import 'package:senapath/features/logistics/domain/event_time_converter.dart';
import 'package:senapath/features/logistics/domain/logistics_models.dart';
import 'package:senapath/features/logistics/presentation/logistics_cubit.dart';

void main() {
  test('refreshes and persists the latest daily reference rates', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = LogisticsRepository(database);
    final cubit = LogisticsCubit(
      repository,
      rateProvider: _FakeExchangeRateProvider(
        ExchangeRateSnapshot(
          rates: const {
            BudgetCurrency.eur: 1,
            BudgetCurrency.idr: 20325,
            BudgetCurrency.usd: 1.1345,
            BudgetCurrency.chf: 0.94635,
            BudgetCurrency.myr: 4.95,
          },
          asOf: DateTime.utc(2026, 10, 1),
        ),
      ),
    );
    await cubit.load();

    await cubit.refreshRates();

    expect(cubit.state.data.eurRates[BudgetCurrency.idr], 20325);
    expect(cubit.state.data.rateSource, 'Frankfurter');
    expect(cubit.state.data.rateUpdatedAt, DateTime.utc(2026, 10, 1));

    await cubit.close();
    await database.close();
  });

  test('parses the latest Frankfurter rates and uses the oldest quote date', () {
    final rows = [
      for (final currency in BudgetCurrency.values)
        if (currency != BudgetCurrency.eur)
          '{"date":"${currency == BudgetCurrency.usd ? '2026-10-02' : '2026-10-01'}",'
              '"base":"EUR","quote":"${currency.code}",'
              '"rate":${switch (currency) {
                BudgetCurrency.idr => 20325,
                BudgetCurrency.usd => 1.1345,
                BudgetCurrency.chf => 0.94635,
                BudgetCurrency.myr => 4.95,
                _ => 1.5,
              }}}',
    ].join(',');
    final snapshot = ExchangeRateSnapshot.fromJson('[$rows]');

    expect(snapshot.rates[BudgetCurrency.idr], 20325);
    expect(snapshot.rates[BudgetCurrency.usd], 1.1345);
    expect(snapshot.rates[BudgetCurrency.chf], 0.94635);
    expect(snapshot.rates[BudgetCurrency.myr], 4.95);
    expect(snapshot.asOf, DateTime.utc(2026, 10, 1));
  });

  test('rejects an incomplete Frankfurter response', () {
    expect(
      () => ExchangeRateSnapshot.fromJson(
        '[{"date":"2026-10-01","base":"EUR","quote":"USD","rate":1.1}]',
      ),
      throwsFormatException,
    );
  });

  test('retries a non-JSON AI estimate and accepts fenced JSON', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final gateway = _FakeAiChatGateway([
      'Air minum biasanya sekitar 2 sampai 4 MYR.',
      '```json\n{"items":[{"id":"water","low":2,"high":4,'
          '"currency":"MYR"}]}\n```',
    ]);
    final cubit = LogisticsCubit(
      LogisticsRepository(database),
      aiChatGateway: gateway,
    );
    await cubit.load();

    final estimates = await cubit.estimateResupplyPrices(
      items: const {'water': 'Air minum 1,5 L'},
      localCurrency: BudgetCurrency.myr,
      baseCurrency: BudgetCurrency.idr,
      areaHint: 'Kuala Lumpur',
    );

    expect(estimates, hasLength(1));
    expect(estimates.single.low, 2);
    expect(estimates.single.high, 4);
    expect(gateway.callCount, 2);
    expect(gateway.lastMessages.last.content, contains('JSON valid'));

    await cubit.close();
    await database.close();
  });

  test('fails clearly after AI returns invalid structure twice', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final gateway = _FakeAiChatGateway(['Harga 2-4 MYR', 'tetap tidak valid']);
    final cubit = LogisticsCubit(
      LogisticsRepository(database),
      aiChatGateway: gateway,
    );
    await cubit.load();

    await expectLater(
      cubit.estimateResupplyPrices(
        items: const {'water': 'Air minum 1,5 L'},
        localCurrency: BudgetCurrency.myr,
        baseCurrency: BudgetCurrency.idr,
        areaHint: '',
      ),
      throwsFormatException,
    );
    expect(gateway.callCount, 2);

    await cubit.close();
    await database.close();
  });

  group('budget conversion', () {
    test('converts amounts through EUR rates and totals multiple items', () {
      const rates = {
        BudgetCurrency.eur: 1.0,
        BudgetCurrency.usd: 1.1,
        BudgetCurrency.idr: 17000.0,
        BudgetCurrency.chf: 0.95,
      };
      const items = [
        BudgetItem(
          id: 'hotel',
          name: 'Hotel',
          amount: 100,
          currency: BudgetCurrency.eur,
        ),
        BudgetItem(
          id: 'transport',
          name: 'Transport',
          amount: 55,
          currency: BudgetCurrency.usd,
        ),
      ];

      expect(
        BudgetCalculator.convert(
          amount: 10,
          from: BudgetCurrency.eur,
          to: BudgetCurrency.chf,
          eurRates: rates,
        ),
        9.5,
      );
      expect(
        BudgetCalculator.convert(
          amount: 2,
          from: BudgetCurrency.myr,
          to: BudgetCurrency.idr,
          eurRates: {...rates, BudgetCurrency.myr: 4.5},
        ),
        closeTo(7555.5555, 0.001),
      );
      expect(
        BudgetCalculator.total(
          items: items,
          target: BudgetCurrency.eur,
          eurRates: rates,
        ),
        closeTo(150, 0.0001),
      );
    });

    test('does not invent missing rates', () {
      expect(
        BudgetCalculator.convert(
          amount: 10,
          from: BudgetCurrency.eur,
          to: BudgetCurrency.usd,
          eurRates: const {BudgetCurrency.eur: 1},
        ),
        isNull,
      );
    });

    test('totals actual expenses separately from planned allocations', () {
      const rates = {
        BudgetCurrency.eur: 1.0,
        BudgetCurrency.usd: 1.1,
        BudgetCurrency.idr: 17000.0,
      };
      final expenses = [
        BudgetExpense(
          id: 'meal-1',
          budgetItemId: 'food',
          amount: 22,
          currency: BudgetCurrency.usd,
          spentAt: DateTime.utc(2026, 10, 12),
          note: 'Makan siang',
        ),
        BudgetExpense(
          id: 'meal-2',
          budgetItemId: 'food',
          amount: 100000,
          currency: BudgetCurrency.idr,
          spentAt: DateTime.utc(2026, 10, 12),
        ),
      ];

      expect(
        BudgetCalculator.expenseTotal(
          expenses: expenses,
          target: BudgetCurrency.usd,
          eurRates: rates,
        ),
        closeTo(28.470588, 0.00001),
      );
      expect(
        BudgetCalculator.expenseTotal(
          expenses: expenses,
          target: BudgetCurrency.jpy,
          eurRates: rates,
        ),
        isNull,
      );
      expect(BudgetCurrency.values.length, greaterThan(20));
    });
  });

  group('event time conversion', () {
    final converter = EventTimeConverter();

    test('rejects a local time skipped by the London spring DST change', () {
      final result = converter.resolveLocalTime(
        DateTime(2026, 3, 29, 1, 30),
        EventTimeZone.london,
      );

      expect(result.isNonexistent, isTrue);
    });

    test('returns both instants for an ambiguous London autumn time', () {
      final result = converter.resolveLocalTime(
        DateTime(2026, 10, 25, 1, 30),
        EventTimeZone.london,
      );

      expect(result.isAmbiguous, isTrue);
      expect(result.instants, hasLength(2));
      expect(
        result.instants[1].millisecondsSinceEpoch -
            result.instants[0].millisecondsSinceEpoch,
        const Duration(hours: 1).inMilliseconds,
      );
    });

    test('converts an instant across the date boundary', () {
      final source = converter.resolveLocalTime(
        DateTime(2026, 1, 1, 23, 30),
        EventTimeZone.london,
      );
      final wit = converter.convertInstant(
        source.instants.single,
        EventTimeZone.wit,
      );

      expect(wit.year, 2026);
      expect(wit.month, 1);
      expect(wit.day, 2);
      expect(wit.hour, 8);
      expect(wit.minute, 30);
    });

    test('supports searchable IANA zones outside the preset destinations', () {
      final newYork = EventTimeZone.fromIanaName('America/New_York');

      expect(EventTimeZone.all, isNotEmpty);
      expect(
        EventTimeZone.all.any((zone) => zone.ianaName == 'America/New_York'),
        isTrue,
      );
      expect(newYork, isNotNull);
      expect(
        converter
            .resolveLocalTime(DateTime(2026, 3, 8, 2, 30), newYork!)
            .isNonexistent,
        isTrue,
      );
      expect(EventTimeZone.fromIanaName('Not/A_Timezone'), isNull);
    });
  });

  test('persists budget items and manual rates across cubit reloads', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = LogisticsRepository(database);
    final cubit = LogisticsCubit(repository);
    await cubit.load();
    await cubit.upsertItem(
      const BudgetItem(
        id: 'transport',
        name: 'Transport',
        amount: 55,
        currency: BudgetCurrency.usd,
      ),
    );
    await cubit.upsertExpense(
      BudgetExpense(
        id: 'transport-ride',
        budgetItemId: 'transport',
        amount: 12.5,
        currency: BudgetCurrency.usd,
        spentAt: DateTime.utc(2026, 10, 12, 8),
        note: 'Tiket ferry',
      ),
    );
    await cubit.upsertCustomResupplyItem(
      const CustomResupplyItem(id: 'custom-energy-gel', name: 'Energy gel'),
    );
    await cubit.updateRates(const {
      BudgetCurrency.idr: 17000,
      BudgetCurrency.usd: 1.1,
      BudgetCurrency.chf: 0.95,
      BudgetCurrency.myr: 4.5,
    });
    await cubit.setTargetCurrency(BudgetCurrency.chf);
    await cubit.setBaseCurrency(BudgetCurrency.usd);
    await cubit.setBaseTimeZone('Europe/London');

    final restoredCubit = LogisticsCubit(repository);
    await restoredCubit.load();

    expect(restoredCubit.state.data.items.single.name, 'Transport');
    expect(restoredCubit.state.data.expenses.single.note, 'Tiket ferry');
    expect(restoredCubit.state.data.expenses.single.amount, 12.5);
    expect(
      restoredCubit.state.data.customResupplyItems.single.name,
      'Energy gel',
    );
    expect(restoredCubit.state.data.eurRates[BudgetCurrency.usd], 1.1);
    expect(restoredCubit.state.data.rateUpdatedAt, isNotNull);
    expect(restoredCubit.state.data.targetCurrency, BudgetCurrency.chf);
    expect(restoredCubit.state.data.baseCurrency, BudgetCurrency.usd);
    expect(restoredCubit.state.data.baseTimeZoneIanaName, 'Europe/London');

    await restoredCubit.removeItem('transport');
    expect(restoredCubit.state.data.expenses, isEmpty);
    await restoredCubit.removeCustomResupplyItem('custom-energy-gel');
    expect(restoredCubit.state.data.customResupplyItems, isEmpty);

    await restoredCubit.close();
    await cubit.close();
    await database.close();
  });
}

class _FakeExchangeRateProvider implements ExchangeRateProvider {
  const _FakeExchangeRateProvider(this.snapshot);

  final ExchangeRateSnapshot snapshot;

  @override
  Future<ExchangeRateSnapshot> fetchLatest() async => snapshot;
}

class _FakeAiChatGateway implements AiChatGateway {
  _FakeAiChatGateway(this.responses);

  final List<String> responses;
  int callCount = 0;
  List<AiChatMessage> lastMessages = const [];

  @override
  bool get isConfigured => true;

  @override
  Future<String> send({
    required List<AiChatMessage> messages,
    required Map<String, Object?> context,
  }) async {
    lastMessages = messages;
    if (callCount >= responses.length) {
      throw StateError('No fake AI response configured for this call.');
    }
    return responses[callCount++];
  }
}
