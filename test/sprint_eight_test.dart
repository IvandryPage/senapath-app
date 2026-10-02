import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:senapath/core/storage/app_database.dart';
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

  test(
    'parses the latest Frankfurter rates and uses the oldest quote date',
    () {
      final snapshot = ExchangeRateSnapshot.fromJson(
        '[{"date":"2026-10-01","base":"EUR","quote":"CHF","rate":0.94635},'
        '{"date":"2026-10-01","base":"EUR","quote":"IDR","rate":20325},'
        '{"date":"2026-10-02","base":"EUR","quote":"USD","rate":1.1345}]',
      );

      expect(snapshot.rates[BudgetCurrency.idr], 20325);
      expect(snapshot.rates[BudgetCurrency.usd], 1.1345);
      expect(snapshot.rates[BudgetCurrency.chf], 0.94635);
      expect(snapshot.asOf, DateTime.utc(2026, 10, 1));
    },
  );

  test('rejects an incomplete Frankfurter response', () {
    expect(
      () => ExchangeRateSnapshot.fromJson(
        '[{"date":"2026-10-01","base":"EUR","quote":"USD","rate":1.1}]',
      ),
      throwsFormatException,
    );
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
        EventTimeZone.all.any(
          (zone) => zone.ianaName == 'America/New_York',
        ),
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
    await cubit.updateRates(const {
      BudgetCurrency.idr: 17000,
      BudgetCurrency.usd: 1.1,
      BudgetCurrency.chf: 0.95,
    });
    await cubit.setTargetCurrency(BudgetCurrency.chf);

    final restoredCubit = LogisticsCubit(repository);
    await restoredCubit.load();

    expect(restoredCubit.state.data.items.single.name, 'Transport');
    expect(restoredCubit.state.data.eurRates[BudgetCurrency.usd], 1.1);
    expect(restoredCubit.state.data.rateUpdatedAt, isNotNull);
    expect(restoredCubit.state.data.targetCurrency, BudgetCurrency.chf);

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
