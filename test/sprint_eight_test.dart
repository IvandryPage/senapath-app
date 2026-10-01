import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:senapath/core/storage/app_database.dart';
import 'package:senapath/features/logistics/data/logistics_repository.dart';
import 'package:senapath/features/logistics/domain/event_time_converter.dart';
import 'package:senapath/features/logistics/domain/logistics_models.dart';
import 'package:senapath/features/logistics/presentation/logistics_cubit.dart';

void main() {
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
