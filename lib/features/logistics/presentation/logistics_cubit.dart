import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../assistant/data/ai_chat_gateway.dart';
import '../../assistant/domain/ai_chat_message.dart';
import '../../../core/validation/validators.dart';
import '../data/exchange_rate_service.dart';
import '../data/logistics_repository.dart';
import '../domain/event_time_converter.dart';
import '../domain/logistics_models.dart';

class LogisticsState {
  const LogisticsState({
    this.data = const LogisticsData(),
    this.isLoaded = false,
    this.isLoading = false,
    this.isSaving = false,
    this.isRefreshingRates = false,
    this.error,
  });

  final LogisticsData data;
  final bool isLoaded;
  final bool isLoading;
  final bool isSaving;
  final bool isRefreshingRates;
  final String? error;
}

class LogisticsCubit extends Cubit<LogisticsState> {
  LogisticsCubit(
    this._repository, {
    ExchangeRateProvider? rateProvider,
    this._aiChatGateway,
  }) : _rateProvider = rateProvider ?? FrankfurterExchangeRateService(),
       super(const LogisticsState());

  final LogisticsRepository _repository;
  final ExchangeRateProvider _rateProvider;
  final AiChatGateway? _aiChatGateway;

  Future<void> load() async {
    if (state.isLoaded || state.isLoading) return;
    emit(const LogisticsState(isLoading: true));
    try {
      emit(LogisticsState(data: await _repository.load(), isLoaded: true));
    } catch (_) {
      emit(
        const LogisticsState(
          error: 'Data logistik tidak dapat dibaca. Coba muat ulang.',
        ),
      );
    }
  }

  Future<void> upsertItem(BudgetItem item) async {
    final name = item.name.trim();
    if (item.id.trim().isEmpty ||
        name.isEmpty ||
        name.runes.length > InputLimits.itemNameMaxLength) {
      throw ArgumentError.value(
        item.name,
        'name',
        'Use 1 to ${InputLimits.itemNameMaxLength} characters.',
      );
    }
    if (!item.amount.isFinite ||
        item.amount <= 0 ||
        item.amount > InputLimits.moneyMaxAmount) {
      throw ArgumentError.value(
        item.amount,
        'amount',
        'Use a positive amount within the allowed limit.',
      );
    }
    final normalized = BudgetItem(
      id: item.id,
      name: name,
      amount: item.amount,
      currency: item.currency,
    );
    final items = [...state.data.items];
    final index = items.indexWhere((existing) => existing.id == item.id);
    if (index == -1) {
      items.add(normalized);
    } else {
      items[index] = normalized;
    }
    await _persist(_copyData(items: items));
  }

  Future<void> removeItem(String id) async {
    await _persist(
      _copyData(
        items: state.data.items.where((item) => item.id != id).toList(),
        expenses: state.data.expenses
            .where((expense) => expense.budgetItemId != id)
            .toList(),
      ),
    );
  }

  Future<void> upsertExpense(BudgetExpense expense) async {
    if (!state.data.items.any((item) => item.id == expense.budgetItemId)) {
      throw ArgumentError.value(
        expense.budgetItemId,
        'budgetItemId',
        'Budget category does not exist.',
      );
    }
    if (!expense.amount.isFinite ||
        expense.amount <= 0 ||
        expense.amount > InputLimits.moneyMaxAmount) {
      throw ArgumentError.value(
        expense.amount,
        'amount',
        'Use a positive amount within the allowed limit.',
      );
    }
    if (expense.note.runes.length > InputLimits.expenseNoteMaxLength ||
        TextValidators.hasForbiddenCharacters(expense.note)) {
      throw ArgumentError.value(expense.note, 'note', 'Invalid note.');
    }
    final expenses = [...state.data.expenses];
    final index = expenses.indexWhere((existing) => existing.id == expense.id);
    if (index == -1) {
      expenses.add(expense);
    } else {
      expenses[index] = expense;
    }
    await _persist(_copyData(expenses: expenses));
  }

  Future<void> removeExpense(String id) async {
    await _persist(
      _copyData(
        expenses: state.data.expenses
            .where((expense) => expense.id != id)
            .toList(),
      ),
    );
  }

  Future<void> upsertCustomResupplyItem(CustomResupplyItem item) async {
    final name = item.name.trim();
    if (item.id.trim().isEmpty ||
        name.isEmpty ||
        name.runes.length > InputLimits.itemNameMaxLength ||
        TextValidators.hasForbiddenCharacters(name)) {
      throw ArgumentError.value(
        item.name,
        'name',
        'Use 1 to ${InputLimits.itemNameMaxLength} characters.',
      );
    }
    final items = [...state.data.customResupplyItems];
    final index = items.indexWhere((existing) => existing.id == item.id);
    final normalized = CustomResupplyItem(id: item.id, name: name);
    if (index == -1) {
      items.add(normalized);
    } else {
      items[index] = normalized;
    }
    await _persist(_copyData(customResupplyItems: items));
  }

  Future<void> removeCustomResupplyItem(String id) async {
    await _persist(
      _copyData(
        customResupplyItems: state.data.customResupplyItems
            .where((item) => item.id != id)
            .toList(),
      ),
    );
  }

  Future<void> updateRates(Map<BudgetCurrency, double> rates) async {
    final updatedRates = {...state.data.eurRates};
    for (final entry in rates.entries) {
      if (entry.key == BudgetCurrency.eur ||
          !entry.value.isFinite ||
          entry.value <= 0 ||
          entry.value > InputLimits.moneyMaxAmount) {
        throw ArgumentError.value(
          entry.value,
          entry.key.code,
          'Rate must be positive.',
        );
      }
      updatedRates[entry.key] = entry.value;
    }
    await _persist(
      _copyData(
        eurRates: {BudgetCurrency.eur: 1, ...updatedRates},
        rateUpdatedAt: DateTime.now(),
        rateSource: 'Manual',
      ),
    );
  }

  Future<void> refreshRates() async {
    if (!state.isLoaded || state.isSaving || state.isRefreshingRates) return;
    emit(
      LogisticsState(data: state.data, isLoaded: true, isRefreshingRates: true),
    );
    try {
      final snapshot = await _rateProvider.fetchLatest();
      await _persist(
        _copyData(
          eurRates: snapshot.rates,
          rateUpdatedAt: snapshot.asOf,
          rateSource: 'Frankfurter',
        ),
      );
    } catch (_) {
      emit(
        LogisticsState(
          data: state.data,
          isLoaded: true,
          error: 'Kurs referensi gagal dimuat. Kurs tersimpan tetap digunakan.',
        ),
      );
    }
  }

  Future<void> setTargetCurrency(BudgetCurrency currency) async {
    await _persist(_copyData(targetCurrency: currency));
  }

  Future<void> setBaseCurrency(BudgetCurrency currency) async {
    final updated = state.data.conversionCurrencies
        .where((existing) => existing != currency)
        .toList();
    await _persist(
      _copyData(baseCurrency: currency, conversionCurrencies: updated),
    );
  }

  Future<void> addConversionCurrency(BudgetCurrency currency) async {
    if (currency == state.data.baseCurrency) return;
    final current = state.data.effectiveConversionCurrencies;
    if (current.contains(currency)) return;
    await _persist(_copyData(conversionCurrencies: [...current, currency]));
  }

  Future<void> removeConversionCurrency(BudgetCurrency currency) async {
    final current = state.data.effectiveConversionCurrencies
        .where((existing) => existing != currency)
        .toList();
    if (current.isEmpty) return;
    await _persist(_copyData(conversionCurrencies: current));
  }

  Future<void> setBaseTimeZone(String ianaName) async {
    if (EventTimeZone.fromIanaName(ianaName) == null) {
      throw ArgumentError.value(ianaName, 'ianaName', 'Must not be empty.');
    }
    await _persist(_copyData(baseTimeZoneIanaName: ianaName));
  }

  Future<List<ResupplyPriceEstimate>> estimateResupplyPrices({
    required Map<String, String> items,
    required BudgetCurrency localCurrency,
    required BudgetCurrency baseCurrency,
    required String areaHint,
  }) async {
    final gateway = _aiChatGateway;
    if (gateway == null || !gateway.isConfigured) {
      throw StateError('Layanan AI belum dikonfigurasi.');
    }
    if (items.isEmpty || items.length > 8) {
      throw ArgumentError.value(items, 'items', 'Pilih 1 sampai 8 kebutuhan.');
    }
    final normalizedArea = areaHint.trim();
    if (normalizedArea.length > InputLimits.areaHintMaxLength ||
        TextValidators.hasForbiddenCharacters(normalizedArea)) {
      throw ArgumentError.value(
        areaHint,
        'areaHint',
        'Area hint is too long or invalid.',
      );
    }
    final request =
        'Estimasi kisaran harga non-real-time untuk barang ini: '
        '${jsonEncode(items)}. Mata uang lokal ${localCurrency.code}; '
        'wilayah ${normalizedArea.isEmpty ? 'tidak diketahui' : normalizedArea}. '
        'Kembalikan satu objek JSON saja dengan bentuk '
        '{"items":[{"id":"...","low":angka,"high":angka,'
        '"currency":"${localCurrency.code}"}]}. Jangan gunakan Markdown, '
        'code fence, atau teks tambahan. Gunakan hanya id yang diberikan. '
        'Jangan mengarang harga toko, data terkini, atau sumber/sitasi. '
        'Jika kisaran tidak dapat diperkirakan secara bertanggung jawab, '
        'jangan sertakan item itu. Angka adalah indikasi sangat kasar dari '
        'pengetahuan umum dan bukan hasil pencarian harga real-time.';
    final context = {
      'feature': 'cycling-resupply-price-estimate',
      'localCurrency': localCurrency.code,
      'comparisonCurrency': baseCurrency.code,
    };
    final allowedIds = items.keys.toSet();

    final raw = await gateway.send(
      messages: [AiChatMessage(role: 'user', content: request)],
      context: context,
    );
    try {
      return _parseResupplyEstimates(raw, allowedIds, localCurrency);
    } on FormatException {
      final retry = await gateway.send(
        messages: [
          AiChatMessage(role: 'user', content: request),
          AiChatMessage(
            role: 'assistant',
            content: raw.length > 2000 ? raw.substring(0, 2000) : raw,
          ),
          const AiChatMessage(
            role: 'user',
            content:
                'Respons tadi tidak bisa dibaca sebagai data. Ulangi '
                'dengan satu objek JSON valid saja, tanpa Markdown atau teks '
                'tambahan. Mantapkan nama field id, low, high, currency dan '
                'pastikan angka berupa JSON number.',
          ),
        ],
        context: context,
      );
      return _parseResupplyEstimates(retry, allowedIds, localCurrency);
    }
  }

  List<ResupplyPriceEstimate> _parseResupplyEstimates(
    String raw,
    Set<String> allowedIds,
    BudgetCurrency localCurrency,
  ) {
    final decoded = _decodeJsonPayload(raw);
    final rawItems = decoded is Map
        ? decoded['items'] ?? decoded['estimates']
        : decoded;
    if (rawItems is! List) {
      throw const FormatException('Format estimasi harga AI tidak valid.');
    }

    final estimates = <ResupplyPriceEstimate>[];
    for (final item in rawItems) {
      if (item is! Map) {
        throw const FormatException(
          'Barang pada respons harga AI tidak valid.',
        );
      }
      final id = item['id'] ?? item['itemId'];
      if (id is! String || !allowedIds.contains(id)) {
        throw const FormatException(
          'Barang pada respons harga AI tidak valid.',
        );
      }
      final low = _parseEstimateNumber(item['low'] ?? item['min']);
      final high = _parseEstimateNumber(item['high'] ?? item['max']);
      final currency = BudgetCurrency.fromCode(item['currency'] as String?);
      if (low == null ||
          high == null ||
          !low.isFinite ||
          !high.isFinite ||
          low < 0 ||
          high < low ||
          currency != localCurrency) {
        throw const FormatException('Nilai estimasi harga AI tidak valid.');
      }
      estimates.add(
        ResupplyPriceEstimate(
          itemId: id,
          low: low,
          high: high,
          currency: currency!,
        ),
      );
    }
    if (estimates.isEmpty) {
      throw const FormatException(
        'AI tidak dapat memperkirakan harga barang ini.',
      );
    }
    return estimates;
  }

  Object? _decodeJsonPayload(String raw) {
    final trimmed = raw.trim().replaceFirst('\uFEFF', '');
    if (trimmed.isEmpty) {
      throw const FormatException('AI tidak mengembalikan data.');
    }
    final candidates = <String>[trimmed];
    final codeBlocks = RegExp(
      r'```(?:json)?\s*([\s\S]*?)```',
      caseSensitive: false,
    );
    for (final match in codeBlocks.allMatches(trimmed)) {
      final block = match.group(1)?.trim();
      if (block != null && block.isNotEmpty) candidates.insert(0, block);
    }
    for (final candidate in candidates) {
      try {
        final decoded = jsonDecode(candidate);
        if (decoded is Map || decoded is List) return decoded;
      } on FormatException {
        // Try extracting a balanced JSON object from surrounding prose.
      }
      final object = _firstJsonObject(candidate);
      if (object == null) continue;
      try {
        final decoded = jsonDecode(object);
        if (decoded is Map || decoded is List) return decoded;
      } on FormatException {
        // Continue to other candidate blocks before asking the model to retry.
      }
    }
    throw const FormatException('AI tidak mengembalikan JSON yang valid.');
  }

  String? _firstJsonObject(String value) {
    var start = -1;
    var depth = 0;
    var inString = false;
    var isEscaped = false;
    for (var index = 0; index < value.length; index++) {
      final character = value[index];
      if (inString) {
        if (isEscaped) {
          isEscaped = false;
        } else if (character == '\\') {
          isEscaped = true;
        } else if (character == '"') {
          inString = false;
        }
        continue;
      }
      if (character == '"') {
        inString = true;
      } else if (character == '{') {
        if (depth == 0) start = index;
        depth++;
      } else if (character == '}' && depth > 0) {
        depth--;
        if (depth == 0 && start >= 0) {
          return value.substring(start, index + 1);
        }
      }
    }
    return null;
  }

  double? _parseEstimateNumber(Object? value) {
    if (value is num) return value.toDouble();
    if (value is! String) return null;
    final normalized = value.trim().replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  LogisticsData _copyData({
    List<BudgetItem>? items,
    List<BudgetExpense>? expenses,
    List<CustomResupplyItem>? customResupplyItems,
    Map<BudgetCurrency, double>? eurRates,
    DateTime? rateUpdatedAt,
    String? rateSource,
    BudgetCurrency? targetCurrency,
    BudgetCurrency? baseCurrency,
    List<BudgetCurrency>? conversionCurrencies,
    String? baseTimeZoneIanaName,
  }) => LogisticsData(
    items: items ?? state.data.items,
    expenses: expenses ?? state.data.expenses,
    customResupplyItems: customResupplyItems ?? state.data.customResupplyItems,
    eurRates: eurRates ?? state.data.eurRates,
    rateUpdatedAt: rateUpdatedAt ?? state.data.rateUpdatedAt,
    rateSource: rateSource ?? state.data.rateSource,
    targetCurrency: targetCurrency ?? state.data.targetCurrency,
    baseCurrency: baseCurrency ?? state.data.baseCurrency,
    conversionCurrencies:
        conversionCurrencies ?? state.data.conversionCurrencies,
    baseTimeZoneIanaName:
        baseTimeZoneIanaName ?? state.data.baseTimeZoneIanaName,
  );

  Future<void> _persist(LogisticsData next) async {
    final previous = state.data;
    emit(
      LogisticsState(data: previous, isLoaded: state.isLoaded, isSaving: true),
    );
    try {
      await _repository.save(next);
      emit(LogisticsState(data: next, isLoaded: true));
    } catch (_) {
      emit(
        LogisticsState(
          data: previous,
          isLoaded: true,
          error: 'Perubahan belum tersimpan. Coba lagi.',
        ),
      );
    }
  }
}
