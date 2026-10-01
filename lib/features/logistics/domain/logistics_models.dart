enum BudgetCurrency {
  eur('EUR'),
  idr('IDR'),
  usd('USD'),
  chf('CHF');

  const BudgetCurrency(this.code);

  final String code;

  static BudgetCurrency? fromCode(String? code) {
    for (final currency in values) {
      if (currency.code == code) return currency;
    }
    return null;
  }
}

class BudgetItem {
  const BudgetItem({
    required this.id,
    required this.name,
    required this.amount,
    required this.currency,
  });

  final String id;
  final String name;
  final double amount;
  final BudgetCurrency currency;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'amount': amount,
    'currency': currency.code,
  };

  factory BudgetItem.fromJson(Map<String, Object?> json) {
    final currency = BudgetCurrency.fromCode(json['currency'] as String?);
    final amount = (json['amount'] as num?)?.toDouble();
    if (currency == null || amount == null || !amount.isFinite || amount < 0) {
      throw const FormatException('Invalid budget item.');
    }
    return BudgetItem(
      id: json['id'] as String,
      name: json['name'] as String,
      amount: amount,
      currency: currency,
    );
  }
}

class LogisticsData {
  const LogisticsData({
    this.items = const [],
    this.eurRates = const {BudgetCurrency.eur: 1},
    this.rateUpdatedAt,
    this.rateSource = 'Manual',
    this.targetCurrency = BudgetCurrency.eur,
  });

  final List<BudgetItem> items;

  /// Rates express how many units of a currency equal one EUR.
  final Map<BudgetCurrency, double> eurRates;
  final DateTime? rateUpdatedAt;
  final String rateSource;
  final BudgetCurrency targetCurrency;

  Map<String, Object?> toJson() => {
    'items': items.map((item) => item.toJson()).toList(),
    'eurRates': {
      for (final entry in eurRates.entries) entry.key.code: entry.value,
    },
    'rateUpdatedAt': rateUpdatedAt?.toUtc().toIso8601String(),
    'rateSource': rateSource,
    'targetCurrency': targetCurrency.code,
  };

  factory LogisticsData.fromJson(Map<String, Object?> json) {
    final rawItems = json['items'];
    final rawRates = json['eurRates'];
    final rawTarget = json['targetCurrency'] as String?;
    final rawRateSource = json['rateSource'];
    final target = BudgetCurrency.fromCode(rawTarget);
    final rates = <BudgetCurrency, double>{BudgetCurrency.eur: 1};

    if (rawItems is! List ||
        rawRates is! Map ||
        target == null ||
        (rawRateSource != null && rawRateSource is! String)) {
      throw const FormatException('Invalid logistics data.');
    }
    for (final rawItem in rawItems) {
      if (rawItem is! Map) throw const FormatException('Invalid budget item.');
    }
    for (final entry in rawRates.entries) {
      final currency = BudgetCurrency.fromCode(entry.key as String?);
      final rate = (entry.value as num?)?.toDouble();
      if (currency == null || rate == null || !rate.isFinite || rate <= 0) {
        throw const FormatException('Invalid exchange rate.');
      }
      rates[currency] = currency == BudgetCurrency.eur ? 1 : rate;
    }

    final rawUpdatedAt = json['rateUpdatedAt'] as String?;
    final updatedAt = rawUpdatedAt == null
        ? null
        : DateTime.tryParse(rawUpdatedAt);
    if (rawUpdatedAt != null && updatedAt == null) {
      throw const FormatException('Invalid exchange-rate timestamp.');
    }

    return LogisticsData(
      items: [
        for (final rawItem in rawItems)
          BudgetItem.fromJson(Map<String, Object?>.from(rawItem as Map)),
      ],
      eurRates: rates,
      rateUpdatedAt: updatedAt,
      rateSource: rawRateSource as String? ?? 'Manual',
      targetCurrency: target,
    );
  }
}

abstract final class BudgetCalculator {
  static double? convert({
    required double amount,
    required BudgetCurrency from,
    required BudgetCurrency to,
    required Map<BudgetCurrency, double> eurRates,
  }) {
    if (!amount.isFinite || amount < 0) return null;
    if (from == to) return amount;
    final fromRate = from == BudgetCurrency.eur ? 1 : eurRates[from];
    final toRate = to == BudgetCurrency.eur ? 1 : eurRates[to];
    if (fromRate == null || toRate == null || fromRate <= 0 || toRate <= 0) {
      return null;
    }
    return amount / fromRate * toRate;
  }

  static double? total({
    required Iterable<BudgetItem> items,
    required BudgetCurrency target,
    required Map<BudgetCurrency, double> eurRates,
  }) {
    var sum = 0.0;
    for (final item in items) {
      final converted = convert(
        amount: item.amount,
        from: item.currency,
        to: target,
        eurRates: eurRates,
      );
      if (converted == null) return null;
      sum += converted;
    }
    return sum;
  }
}
