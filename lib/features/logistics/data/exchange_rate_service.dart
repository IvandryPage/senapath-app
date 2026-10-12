import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/logistics_models.dart';

class ExchangeRateSnapshot {
  const ExchangeRateSnapshot({required this.rates, required this.asOf});

  final Map<BudgetCurrency, double> rates;
  final DateTime asOf;

  factory ExchangeRateSnapshot.fromJson(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! List) {
      throw const FormatException('Invalid exchange-rate response.');
    }

    final rates = <BudgetCurrency, double>{BudgetCurrency.eur: 1};
    final dates = <DateTime>[];
    for (final row in decoded) {
      if (row is! Map || row['base'] != 'EUR') {
        throw const FormatException('Invalid exchange-rate row.');
      }
      final currency = BudgetCurrency.fromCode(row['quote'] as String?);
      final rate = (row['rate'] as num?)?.toDouble();
      final date = DateTime.tryParse(row['date'] as String? ?? '');
      if (currency == null ||
          currency == BudgetCurrency.eur ||
          rate == null ||
          !rate.isFinite ||
          rate <= 0 ||
          date == null) {
        throw const FormatException('Invalid exchange-rate row.');
      }
      rates[currency] = rate;
      dates.add(DateTime.utc(date.year, date.month, date.day));
    }

    final requiredCurrencies = BudgetCurrency.values.where(
      (currency) => currency != BudgetCurrency.eur,
    );
    if (requiredCurrencies.any((currency) => !rates.containsKey(currency)) ||
        dates.isEmpty) {
      throw const FormatException('Exchange-rate response is incomplete.');
    }

    dates.sort();
    return ExchangeRateSnapshot(rates: rates, asOf: dates.first);
  }
}

abstract interface class ExchangeRateProvider {
  Future<ExchangeRateSnapshot> fetchLatest();
}

class FrankfurterExchangeRateService implements ExchangeRateProvider {
  FrankfurterExchangeRateService({this._client});

  static final _uri = Uri.https('api.frankfurter.dev', '/v2/rates', {
    'base': 'EUR',
    'quotes': BudgetCurrency.values
        .where((currency) => currency != BudgetCurrency.eur)
        .map((currency) => currency.code)
        .join(','),
  });

  final http.Client? _client;

  @override
  Future<ExchangeRateSnapshot> fetchLatest() async {
    final client = _client ?? http.Client();
    try {
      final response = await client
          .get(_uri)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw StateError('Exchange-rate service unavailable.');
      }
      return ExchangeRateSnapshot.fromJson(response.body);
    } finally {
      if (_client == null) client.close();
    }
  }
}
