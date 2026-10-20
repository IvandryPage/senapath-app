import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/logistics/domain/logistics_models.dart';

void main() {
  group('BudgetCurrency', () {
    test('exposes decimal digits per currency', () {
      expect(BudgetCurrency.idr.decimalDigits, 0);
      expect(BudgetCurrency.jpy.decimalDigits, 0);
      expect(BudgetCurrency.eur.decimalDigits, 2);
      expect(BudgetCurrency.usd.decimalDigits, 2);
    });

    test('looks up currencies by code, tolerating nulls', () {
      expect(BudgetCurrency.fromCode('IDR'), BudgetCurrency.idr);
      expect(BudgetCurrency.fromCode('tryCurrency'), isNull);
      expect(BudgetCurrency.fromCode('XXX'), isNull);
      expect(BudgetCurrency.fromCode(null), isNull);
    });

    test('picks default conversion currencies excluding the base', () {
      final defaults = BudgetCurrency.defaultConversionCurrencies(
        BudgetCurrency.usd,
      );
      expect(defaults, [BudgetCurrency.idr, BudgetCurrency.eur]);
      expect(defaults.contains(BudgetCurrency.usd), isFalse);

      final idrDefaults = BudgetCurrency.defaultConversionCurrencies(
        BudgetCurrency.idr,
        count: 3,
      );
      expect(idrDefaults, [
        BudgetCurrency.usd,
        BudgetCurrency.eur,
        BudgetCurrency.gbp,
      ]);

      final all = BudgetCurrency.defaultConversionCurrencies(
        BudgetCurrency.eur,
        count: BudgetCurrency.values.length,
      );
      expect(all, hasLength(BudgetCurrency.values.length - 1));
      expect(all.contains(BudgetCurrency.eur), isFalse);
    });
  });

  group('BudgetItem', () {
    test('round-trips through JSON', () {
      const item = BudgetItem(
        id: 'i1',
        name: 'Hotel',
        amount: 120.5,
        currency: BudgetCurrency.eur,
      );
      final restored = BudgetItem.fromJson(item.toJson());
      expect(restored.id, 'i1');
      expect(restored.amount, 120.5);
      expect(restored.currency, BudgetCurrency.eur);
    });

    test('rejects invalid currencies and amounts', () {
      expect(
        () => BudgetItem.fromJson({
          'id': 'i1',
          'name': 'Hotel',
          'amount': 10,
          'currency': 'XXX',
        }),
        throwsFormatException,
      );
      expect(
        () => BudgetItem.fromJson({
          'id': 'i1',
          'name': 'Hotel',
          'amount': -1,
          'currency': 'EUR',
        }),
        throwsFormatException,
      );
    });
  });

  group('BudgetExpense', () {
    test('round-trips through JSON', () {
      final expense = BudgetExpense(
        id: 'e1',
        budgetItemId: 'i1',
        amount: 25,
        currency: BudgetCurrency.usd,
        spentAt: DateTime.utc(2026, 1, 5),
        note: 'coffee',
      );
      final restored = BudgetExpense.fromJson(expense.toJson());
      expect(restored.id, 'e1');
      expect(restored.budgetItemId, 'i1');
      expect(restored.note, 'coffee');
      expect(restored.spentAt, DateTime.utc(2026, 1, 5));
    });

    test('rejects zero, negative or incomplete expenses', () {
      Map<String, Object?> base() => {
        'id': 'e1',
        'budgetItemId': 'i1',
        'amount': 25,
        'currency': 'USD',
        'spentAt': '2026-01-05T00:00:00.000Z',
      };

      expect(
        () => BudgetExpense.fromJson({...base(), 'amount': 0}),
        throwsFormatException,
      );
      expect(
        () => BudgetExpense.fromJson({...base(), 'spentAt': 'nope'}),
        throwsFormatException,
      );
      expect(
        () => BudgetExpense.fromJson({...base(), 'id': '  '}),
        throwsFormatException,
      );
      expect(
        () => BudgetExpense.fromJson({...base(), 'note': 42}),
        throwsFormatException,
      );
    });
  });

  group('CustomResupplyItem', () {
    test('trims names and round-trips', () {
      final item = CustomResupplyItem.fromJson({'id': 'c1', 'name': '  Snacks  '});
      expect(item.name, 'Snacks');
      expect(
        CustomResupplyItem.fromJson(item.toJson()).id,
        'c1',
      );
    });

    test('rejects empty or oversized names', () {
      expect(
        () => CustomResupplyItem.fromJson({'id': 'c1', 'name': ' '}),
        throwsFormatException,
      );
      expect(
        () => CustomResupplyItem.fromJson({'id': 'c1', 'name': 'x' * 61}),
        throwsFormatException,
      );
    });
  });

  group('LogisticsData', () {
    test('round-trips through JSON with defaults preserved', () {
      final updatedAt = DateTime.utc(2026, 1, 5);
      final data = LogisticsData(
        items: const [
          BudgetItem(
            id: 'i1',
            name: 'Visa',
            amount: 50,
            currency: BudgetCurrency.usd,
          ),
        ],
        expenses: [
          BudgetExpense(
            id: 'e1',
            budgetItemId: 'i1',
            amount: 10,
            currency: BudgetCurrency.usd,
            spentAt: DateTime.utc(2026, 1, 4),
          ),
        ],
        customResupplyItems: const [
          CustomResupplyItem(id: 'c1', name: 'Gel'),
        ],
        eurRates: const {BudgetCurrency.eur: 1, BudgetCurrency.usd: 1.1},
        rateUpdatedAt: updatedAt,
        rateSource: 'Frankfurter',
        targetCurrency: BudgetCurrency.usd,
        baseCurrency: BudgetCurrency.idr,
        conversionCurrencies: const [
          BudgetCurrency.usd,
          BudgetCurrency.idr,
          BudgetCurrency.eur,
        ],
        baseTimeZoneIanaName: 'Asia/Makassar',
      );

      final restored = LogisticsData.fromJson(data.toJson());
      expect(restored.items, hasLength(1));
      expect(restored.expenses, hasLength(1));
      expect(restored.customResupplyItems.single.name, 'Gel');
      expect(restored.eurRates[BudgetCurrency.usd], 1.1);
      expect(restored.rateUpdatedAt, updatedAt);
      expect(restored.rateSource, 'Frankfurter');
      expect(restored.targetCurrency, BudgetCurrency.usd);
      expect(restored.baseTimeZoneIanaName, 'Asia/Makassar');
      expect(restored.conversionCurrencies, [
        BudgetCurrency.usd,
        BudgetCurrency.idr,
        BudgetCurrency.eur,
      ]);
    });

    test('forces the EUR rate to 1', () {
      final restored = LogisticsData.fromJson({
        'items': <Object?>[],
        'eurRates': {
          'EUR': 5,
          'USD': 1.1,
        },
        'targetCurrency': 'EUR',
        'baseCurrency': 'IDR',
      });
      expect(restored.eurRates[BudgetCurrency.eur], 1);
      expect(restored.eurRates[BudgetCurrency.usd], 1.1);
      expect(restored.rateSource, 'Manual');
      expect(restored.baseTimeZoneIanaName, 'Asia/Jakarta');
    });

    test('rejects invalid exchange rates', () {
      expect(
        () => LogisticsData.fromJson({
          'items': <Object?>[],
          'eurRates': {'XXX': 1},
          'targetCurrency': 'EUR',
        }),
        throwsFormatException,
      );
      expect(
        () => LogisticsData.fromJson({
          'items': <Object?>[],
          'eurRates': {'USD': 0},
          'targetCurrency': 'EUR',
        }),
        throwsFormatException,
      );
    });

    test('rejects malformed top-level payloads', () {
      expect(
        () => LogisticsData.fromJson({
          'items': 'x',
          'eurRates': <String, Object?>{},
          'targetCurrency': 'EUR',
        }),
        throwsFormatException,
      );
      expect(
        () => LogisticsData.fromJson({
          'items': <Object?>[],
          'eurRates': <String, Object?>{},
          'targetCurrency': 'XXX',
        }),
        throwsFormatException,
      );
      expect(
        () => LogisticsData.fromJson({
          'items': <Object?>[],
          'eurRates': {'USD': -1},
          'targetCurrency': 'EUR',
        }),
        throwsFormatException,
      );
      expect(
        () => LogisticsData.fromJson({
          'items': <Object?>[],
          'eurRates': <String, Object?>{},
          'targetCurrency': 'EUR',
          'rateUpdatedAt': 'not-a-date',
        }),
        throwsFormatException,
      );
      expect(
        () => LogisticsData.fromJson({
          'items': [42],
          'eurRates': <String, Object?>{},
          'targetCurrency': 'EUR',
        }),
        throwsFormatException,
      );
      expect(
        () => LogisticsData.fromJson({
          'items': <Object?>[],
          'expenses': [42],
          'eurRates': <String, Object?>{},
          'targetCurrency': 'EUR',
        }),
        throwsFormatException,
      );
      expect(
        () => LogisticsData.fromJson({
          'items': <Object?>[],
          'customResupplyItems': [42],
          'eurRates': <String, Object?>{},
          'targetCurrency': 'EUR',
        }),
        throwsFormatException,
      );
      expect(
        () => LogisticsData.fromJson({
          'items': <Object?>[],
          'eurRates': <String, Object?>{},
          'targetCurrency': 'EUR',
          'conversionCurrencies': 'oops',
        }),
        throwsFormatException,
      );
      expect(
        () => LogisticsData.fromJson({
          'items': <Object?>[],
          'eurRates': <String, Object?>{},
          'targetCurrency': 'EUR',
          'baseTimeZoneIanaName': '  ',
        }),
        throwsFormatException,
      );
      expect(
        () => LogisticsData.fromJson({
          'items': <Object?>[],
          'eurRates': <String, Object?>{},
          'targetCurrency': 'EUR',
          'rateSource': 7,
        }),
        throwsFormatException,
      );
    });

    test('defaults conversion currencies based on the base currency', () {
      expect(
        const LogisticsData().effectiveConversionCurrencies,
        [BudgetCurrency.usd, BudgetCurrency.eur],
      );
      expect(
        const LogisticsData(baseCurrency: BudgetCurrency.usd)
            .effectiveConversionCurrencies,
        [BudgetCurrency.idr, BudgetCurrency.eur],
      );
      expect(
        const LogisticsData(
          baseCurrency: BudgetCurrency.idr,
          conversionCurrencies: [BudgetCurrency.idr, BudgetCurrency.usd],
        ).effectiveConversionCurrencies,
        [BudgetCurrency.usd],
      );
    });
  });

  group('BudgetCalculator', () {
    const rates = {BudgetCurrency.eur: 1.0, BudgetCurrency.usd: 2.0};

    test('converts through EUR rates', () {
      expect(
        BudgetCalculator.convert(
          amount: 100,
          from: BudgetCurrency.eur,
          to: BudgetCurrency.usd,
          eurRates: rates,
        ),
        200,
      );
      expect(
        BudgetCalculator.convert(
          amount: 200,
          from: BudgetCurrency.usd,
          to: BudgetCurrency.eur,
          eurRates: rates,
        ),
        100,
      );
      expect(
        BudgetCalculator.convert(
          amount: 50,
          from: BudgetCurrency.usd,
          to: BudgetCurrency.usd,
          eurRates: rates,
        ),
        50,
      );
    });

    test('returns null for invalid inputs or missing rates', () {
      expect(
        BudgetCalculator.convert(
          amount: -1,
          from: BudgetCurrency.eur,
          to: BudgetCurrency.usd,
          eurRates: rates,
        ),
        isNull,
      );
      expect(
        BudgetCalculator.convert(
          amount: 10,
          from: BudgetCurrency.usd,
          to: BudgetCurrency.chf,
          eurRates: rates,
        ),
        isNull,
      );
      expect(
        BudgetCalculator.convert(
          amount: 10,
          from: BudgetCurrency.usd,
          to: BudgetCurrency.eur,
          eurRates: const {BudgetCurrency.usd: 0},
        ),
        isNull,
      );
    });

    test('totals items and expenses in the target currency', () {
      const items = [
        BudgetItem(
          id: 'a',
          name: 'A',
          amount: 10,
          currency: BudgetCurrency.eur,
        ),
        BudgetItem(
          id: 'b',
          name: 'B',
          amount: 20,
          currency: BudgetCurrency.usd,
        ),
      ];
      expect(
        BudgetCalculator.total(
          items: items,
          target: BudgetCurrency.usd,
          eurRates: rates,
        ),
        40,
      );

      final expenses = [
        BudgetExpense(
          id: 'e',
          budgetItemId: 'a',
          amount: 5,
          currency: BudgetCurrency.eur,
          spentAt: DateTime.utc(2026),
        ),
      ];
      expect(
        BudgetCalculator.expenseTotal(
          expenses: expenses,
          target: BudgetCurrency.usd,
          eurRates: rates,
        ),
        10,
      );

      expect(
        BudgetCalculator.total(
          items: const [
            BudgetItem(
              id: 'c',
              name: 'C',
              amount: 1,
              currency: BudgetCurrency.chf,
            ),
          ],
          target: BudgetCurrency.usd,
          eurRates: rates,
        ),
        isNull,
      );
    });
  });
}
