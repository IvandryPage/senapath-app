import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/exchange_rate_service.dart';
import '../data/logistics_repository.dart';
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
  LogisticsCubit(this._repository, {ExchangeRateProvider? rateProvider})
    : _rateProvider = rateProvider ?? FrankfurterExchangeRateService(),
      super(const LogisticsState());

  final LogisticsRepository _repository;
  final ExchangeRateProvider _rateProvider;

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
    final items = [...state.data.items];
    final index = items.indexWhere((existing) => existing.id == item.id);
    if (index == -1) {
      items.add(item);
    } else {
      items[index] = item;
    }
    await _persist(_copyData(items: items));
  }

  Future<void> removeItem(String id) async {
    await _persist(
      _copyData(
        items: state.data.items.where((item) => item.id != id).toList(),
      ),
    );
  }

  Future<void> updateRates(Map<BudgetCurrency, double> rates) async {
    for (final currency in BudgetCurrency.values) {
      if (currency == BudgetCurrency.eur) continue;
      final rate = rates[currency];
      if (rate == null || !rate.isFinite || rate <= 0) {
        throw ArgumentError.value(
          rate,
          currency.code,
          'Rate must be positive.',
        );
      }
    }
    await _persist(
      _copyData(
        eurRates: {
          BudgetCurrency.eur: 1,
          for (final currency in BudgetCurrency.values)
            if (currency != BudgetCurrency.eur) currency: rates[currency]!,
        },
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

  LogisticsData _copyData({
    List<BudgetItem>? items,
    Map<BudgetCurrency, double>? eurRates,
    DateTime? rateUpdatedAt,
    String? rateSource,
    BudgetCurrency? targetCurrency,
  }) => LogisticsData(
    items: items ?? state.data.items,
    eurRates: eurRates ?? state.data.eurRates,
    rateUpdatedAt: rateUpdatedAt ?? state.data.rateUpdatedAt,
    rateSource: rateSource ?? state.data.rateSource,
    targetCurrency: targetCurrency ?? state.data.targetCurrency,
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
