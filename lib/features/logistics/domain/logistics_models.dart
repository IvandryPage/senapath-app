enum BudgetCurrency {
  eur('EUR', 'Euro'),
  idr('IDR', 'Rupiah Indonesia'),
  usd('USD', 'Dolar Amerika Serikat'),
  chf('CHF', 'Franc Swiss'),
  myr('MYR', 'Ringgit Malaysia'),
  aud('AUD', 'Dolar Australia'),
  brl('BRL', 'Real Brasil'),
  cad('CAD', 'Dolar Kanada'),
  cny('CNY', 'Yuan Tiongkok'),
  czk('CZK', 'Koruna Ceko'),
  dkk('DKK', 'Krone Denmark'),
  gbp('GBP', 'Pound Inggris'),
  hkd('HKD', 'Dolar Hong Kong'),
  huf('HUF', 'Forint Hungaria'),
  ils('ILS', 'Shekel Israel'),
  inr('INR', 'Rupee India'),
  isk('ISK', 'Krona Islandia'),
  jpy('JPY', 'Yen Jepang'),
  krw('KRW', 'Won Korea Selatan'),
  mxn('MXN', 'Peso Meksiko'),
  nok('NOK', 'Krone Norwegia'),
  nzd('NZD', 'Dolar Selandia Baru'),
  php('PHP', 'Peso Filipina'),
  pln('PLN', 'Zloty Polandia'),
  ron('RON', 'Leu Rumania'),
  sek('SEK', 'Krona Swedia'),
  sgd('SGD', 'Dolar Singapura'),
  thb('THB', 'Baht Thailand'),
  tryCurrency('TRY', 'Lira Turki'),
  zar('ZAR', 'Rand Afrika Selatan');

  const BudgetCurrency(this.code, this.label);

  final String code;
  final String label;

  int get decimalDigits => switch (this) {
    idr || huf || isk || jpy || krw => 0,
    _ => 2,
  };

  static BudgetCurrency? fromCode(String? code) {
    for (final currency in values) {
      if (currency.code == code) return currency;
    }
    return null;
  }

  /// Priority order used to pick a sensible pair of conversion currencies.
  static const List<BudgetCurrency> _conversionPriority = [
    usd,
    idr,
    eur,
    gbp,
    jpy,
    sgd,
    aud,
    myr,
    thb,
    chf,
  ];

  /// Returns up to [count] default conversion currencies for [base], never
  /// including [base] itself.
  static List<BudgetCurrency> defaultConversionCurrencies(
    BudgetCurrency base, {
    int count = 2,
  }) {
    final result = <BudgetCurrency>[];
    void add(BudgetCurrency currency) {
      if (currency == base || result.contains(currency)) return;
      result.add(currency);
    }

    for (final currency in _conversionPriority) {
      if (result.length >= count) break;
      add(currency);
    }
    for (final currency in values) {
      if (result.length >= count) break;
      add(currency);
    }
    return result;
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

class BudgetExpense {
  const BudgetExpense({
    required this.id,
    required this.budgetItemId,
    required this.amount,
    required this.currency,
    required this.spentAt,
    this.note = '',
  });

  final String id;
  final String budgetItemId;
  final double amount;
  final BudgetCurrency currency;
  final DateTime spentAt;
  final String note;

  Map<String, Object?> toJson() => {
    'id': id,
    'budgetItemId': budgetItemId,
    'amount': amount,
    'currency': currency.code,
    'spentAt': spentAt.toIso8601String(),
    'note': note,
  };

  factory BudgetExpense.fromJson(Map<String, Object?> json) {
    final currency = BudgetCurrency.fromCode(json['currency'] as String?);
    final amount = (json['amount'] as num?)?.toDouble();
    final spentAt = DateTime.tryParse(json['spentAt'] as String? ?? '');
    final id = json['id'];
    final budgetItemId = json['budgetItemId'];
    final note = json['note'];
    if (currency == null ||
        amount == null ||
        !amount.isFinite ||
        amount <= 0 ||
        spentAt == null ||
        id is! String ||
        id.trim().isEmpty ||
        budgetItemId is! String ||
        budgetItemId.trim().isEmpty ||
        (note != null && note is! String)) {
      throw const FormatException('Invalid budget expense.');
    }
    return BudgetExpense(
      id: id,
      budgetItemId: budgetItemId,
      amount: amount,
      currency: currency,
      spentAt: spentAt,
      note: note as String? ?? '',
    );
  }
}

class ResupplyPriceEstimate {
  const ResupplyPriceEstimate({
    required this.itemId,
    required this.low,
    required this.high,
    required this.currency,
  });

  final String itemId;
  final double low;
  final double high;
  final BudgetCurrency currency;
}

class CustomResupplyItem {
  const CustomResupplyItem({required this.id, required this.name});

  final String id;
  final String name;

  Map<String, Object?> toJson() => {'id': id, 'name': name};

  factory CustomResupplyItem.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final name = json['name'];
    if (id is! String ||
        id.trim().isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        name.trim().length > 60) {
      throw const FormatException('Invalid custom resupply item.');
    }
    return CustomResupplyItem(id: id, name: name.trim());
  }
}

class LogisticsData {
  const LogisticsData({
    this.items = const [],
    this.expenses = const [],
    this.customResupplyItems = const [],
    this.eurRates = const {BudgetCurrency.eur: 1},
    this.rateUpdatedAt,
    this.rateSource = 'Manual',
    this.targetCurrency = BudgetCurrency.eur,
    this.baseCurrency = BudgetCurrency.idr,
    this.conversionCurrencies = const [],
    this.baseTimeZoneIanaName = 'Asia/Jakarta',
  });

  final List<BudgetItem> items;
  final List<BudgetExpense> expenses;
  final List<CustomResupplyItem> customResupplyItems;

  /// Rates express how many units of a currency equal one EUR.
  final Map<BudgetCurrency, double> eurRates;
  final DateTime? rateUpdatedAt;
  final String rateSource;
  final BudgetCurrency targetCurrency;
  final BudgetCurrency baseCurrency;

  /// Currencies shown in the base-currency converter. Empty means "use the
  /// two default currencies" derived from [baseCurrency].
  final List<BudgetCurrency> conversionCurrencies;
  final String baseTimeZoneIanaName;

  /// Currencies actually shown in the converter, honouring the user's
  /// selection (or the defaults when none was made) and excluding
  /// [baseCurrency].
  List<BudgetCurrency> get effectiveConversionCurrencies {
    if (conversionCurrencies.isEmpty) {
      return BudgetCurrency.defaultConversionCurrencies(baseCurrency);
    }
    return [
      for (final currency in conversionCurrencies)
        if (currency != baseCurrency) currency,
    ];
  }

  Map<String, Object?> toJson() => {
    'items': items.map((item) => item.toJson()).toList(),
    'expenses': expenses.map((expense) => expense.toJson()).toList(),
    'customResupplyItems': customResupplyItems
        .map((item) => item.toJson())
        .toList(),
    'eurRates': {
      for (final entry in eurRates.entries) entry.key.code: entry.value,
    },
    'rateUpdatedAt': rateUpdatedAt?.toUtc().toIso8601String(),
    'rateSource': rateSource,
    'targetCurrency': targetCurrency.code,
    'baseCurrency': baseCurrency.code,
    'conversionCurrencies': [
      for (final currency in conversionCurrencies) currency.code,
    ],
    'baseTimeZoneIanaName': baseTimeZoneIanaName,
  };

  factory LogisticsData.fromJson(Map<String, Object?> json) {
    final rawItems = json['items'];
    final rawExpenses = json['expenses'] ?? const <Object?>[];
    final rawCustomResupplyItems =
        json['customResupplyItems'] ?? const <Object?>[];
    final rawRates = json['eurRates'];
    final rawTarget = json['targetCurrency'] as String?;
    final rawBaseCurrency = json['baseCurrency'] as String?;
    final rawBaseTimeZone = json['baseTimeZoneIanaName'] as String?;
    final rawConversionCurrencies = json['conversionCurrencies'];
    final rawRateSource = json['rateSource'];
    final target = BudgetCurrency.fromCode(rawTarget);
    final baseCurrency = rawBaseCurrency == null
        ? BudgetCurrency.idr
        : BudgetCurrency.fromCode(rawBaseCurrency);
    final rates = <BudgetCurrency, double>{BudgetCurrency.eur: 1};

    if (rawItems is! List ||
        rawExpenses is! List ||
        rawCustomResupplyItems is! List ||
        rawRates is! Map ||
        target == null ||
        baseCurrency == null ||
        (rawConversionCurrencies != null && rawConversionCurrencies is! List) ||
        (rawBaseTimeZone != null && rawBaseTimeZone.trim().isEmpty) ||
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

    final conversionCurrencies = <BudgetCurrency>[];
    for (final rawCurrency in (rawConversionCurrencies as List?) ?? const []) {
      final currency = rawCurrency is String
          ? BudgetCurrency.fromCode(rawCurrency)
          : null;
      if (currency != null && !conversionCurrencies.contains(currency)) {
        conversionCurrencies.add(currency);
      }
    }

    return LogisticsData(
      items: [
        for (final rawItem in rawItems)
          BudgetItem.fromJson(Map<String, Object?>.from(rawItem as Map)),
      ],
      expenses: [
        for (final rawExpense in rawExpenses)
          if (rawExpense is Map)
            BudgetExpense.fromJson(Map<String, Object?>.from(rawExpense))
          else
            throw const FormatException('Invalid budget expense.'),
      ],
      customResupplyItems: [
        for (final rawItem in rawCustomResupplyItems)
          if (rawItem is Map)
            CustomResupplyItem.fromJson(Map<String, Object?>.from(rawItem))
          else
            throw const FormatException('Invalid custom resupply item.'),
      ],
      eurRates: rates,
      rateUpdatedAt: updatedAt,
      rateSource: rawRateSource as String? ?? 'Manual',
      targetCurrency: target,
      baseCurrency: baseCurrency,
      conversionCurrencies: conversionCurrencies,
      baseTimeZoneIanaName: rawBaseTimeZone ?? 'Asia/Jakarta',
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
    if (fromRate == null ||
        toRate == null ||
        !fromRate.isFinite ||
        !toRate.isFinite ||
        fromRate <= 0 ||
        toRate <= 0) {
      return null;
    }
    final converted = amount / fromRate * toRate;
    return converted.isFinite ? converted : null;
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
    return sum.isFinite ? sum : null;
  }

  static double? expenseTotal({
    required Iterable<BudgetExpense> expenses,
    required BudgetCurrency target,
    required Map<BudgetCurrency, double> eurRates,
  }) {
    var sum = 0.0;
    for (final expense in expenses) {
      final converted = convert(
        amount: expense.amount,
        from: expense.currency,
        to: target,
        eurRates: eurRates,
      );
      if (converted == null) return null;
      sum += converted;
    }
    return sum.isFinite ? sum : null;
  }
}
