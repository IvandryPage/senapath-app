import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/logistics/data/exchange_rate_service.dart';
import 'package:senapath/features/logistics/domain/logistics_models.dart';

String _body(Map<BudgetCurrency, double> rates) => jsonEncode([
  for (final entry in rates.entries)
    {
      'base': 'EUR',
      'quote': entry.key.code,
      'rate': entry.value,
      'date': '2026-01-05',
    },
]);

void main() {
  final completeRates = <BudgetCurrency, double>{
    for (final currency in BudgetCurrency.values)
      if (currency != BudgetCurrency.eur) currency: 1.5,
  };

  group('ExchangeRateSnapshot.fromJson', () {
    test('parses a complete response and pins EUR to 1', () {
      final snapshot = ExchangeRateSnapshot.fromJson(_body(completeRates));
      expect(snapshot.rates[BudgetCurrency.eur], 1);
      expect(snapshot.rates[BudgetCurrency.usd], 1.5);
      expect(snapshot.rates, hasLength(BudgetCurrency.values.length));
      expect(snapshot.asOf, DateTime.utc(2026, 1, 5));
    });

    test('uses the earliest date as the snapshot date', () {
      final rows = [
        for (final entry in completeRates.entries)
          {
            'base': 'EUR',
            'quote': entry.key.code,
            'rate': entry.value,
            'date': entry.key == BudgetCurrency.usd
                ? '2026-01-01'
                : '2026-01-05',
          },
      ];
      final snapshot = ExchangeRateSnapshot.fromJson(jsonEncode(rows));
      expect(snapshot.asOf, DateTime.utc(2026, 1, 1));
    });

    test('rejects responses that are not a list', () {
      expect(
        () => ExchangeRateSnapshot.fromJson('{"rates":{}}'),
        throwsFormatException,
      );
    });

    test('rejects rows with a foreign base', () {
      final rows = [
        for (final entry in completeRates.entries)
          {
            'base': entry.key == BudgetCurrency.usd ? 'USD' : 'EUR',
            'quote': entry.key.code,
            'rate': entry.value,
            'date': '2026-01-05',
          },
      ];
      expect(
        () => ExchangeRateSnapshot.fromJson(jsonEncode(rows)),
        throwsFormatException,
      );
    });

    test('rejects incomplete responses', () {
      final rows = [
        {
          'base': 'EUR',
          'quote': 'USD',
          'rate': 1.1,
          'date': '2026-01-05',
        },
      ];
      expect(
        () => ExchangeRateSnapshot.fromJson(jsonEncode(rows)),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('incomplete'),
          ),
        ),
      );
    });

    test('rejects invalid rates', () {
      final rows = <Map<String, Object?>>[
        for (final entry in completeRates.entries)
          {
            'base': 'EUR',
            'quote': entry.key.code,
            'rate': entry.key == BudgetCurrency.usd ? -1 : entry.value,
            'date': '2026-01-05',
          },
      ];
      expect(
        () => ExchangeRateSnapshot.fromJson(jsonEncode(rows)),
        throwsFormatException,
      );
    });

    test('rejects an empty body', () {
      expect(
        () => ExchangeRateSnapshot.fromJson('[]'),
        throwsFormatException,
      );
    });
  });
}
