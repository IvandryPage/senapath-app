import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/senapath_design.dart';
import '../../../core/validation/input_formatters.dart';
import '../../../core/validation/validators.dart';
import '../domain/event_time_converter.dart';
import '../domain/logistics_models.dart';
import 'amount_input_formatter.dart';
import 'currency_label.dart';
import 'logistics_cubit.dart';

class LogisticsScreen extends StatefulWidget {
  const LogisticsScreen({super.key});

  @override
  State<LogisticsScreen> createState() => _LogisticsScreenState();
}

class _LogisticsScreenState extends State<LogisticsScreen> {
  final _timeConverter = EventTimeConverter();
  final _eurAmountController = TextEditingController(text: '1');
  DateTime _eventTime = DateTime.now();
  EventTimeZone _sourceZone = EventTimeZone.wib;
  List<EventTimeZone> _destinationZones = [...EventTimeZone.destinations];
  int? _selectedOccurrence;
  bool _requestedLoad = false;

  @override
  void dispose() {
    _eurAmountController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requestedLoad) return;
    _requestedLoad = true;
    unawaited(_loadLogistics());
  }

  Future<void> _loadLogistics() async {
    final cubit = context.read<LogisticsCubit>();
    await cubit.load();
    if (!mounted) return;
    final savedZone = EventTimeZone.fromIanaName(
      cubit.state.data.baseTimeZoneIanaName,
    );
    if (savedZone != null) setState(() => _sourceZone = savedZone);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LogisticsCubit, LogisticsState>(
      listenWhen: (previous, current) => previous.error != current.error,
      listener: (context, state) {
        if (state.error == null) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(state.error!)));
      },
      child: BlocBuilder<LogisticsCubit, LogisticsState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!state.isLoaded) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.error ?? 'Memuat data logistik.'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: context.read<LogisticsCubit>().load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Coba lagi'),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Column(
              children: [
                _buildResupplyIntro(context),
                const SizedBox(height: 14),
                _buildBudgetSection(context, state),
                const SizedBox(height: 18),
                ExpansionTile(
                  leading: const Icon(Icons.currency_exchange),
                  title: const Text('Kurs & konversi mata uang'),
                  subtitle: const Text('Alat bantu tambahan'),
                  children: [_buildCurrencySection(context, state)],
                ),
                const SizedBox(height: 8),
                ExpansionTile(
                  leading: const Icon(Icons.schedule),
                  title: const Text('Waktu acara'),
                  subtitle: const Text('Konversi manual antar zona waktu'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _buildTimeSection(context),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildResupplyIntro(BuildContext context) => SenapathCard(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.local_gas_station_outlined,
            color: Theme.of(context).colorScheme.primary,
            size: 28,
          ),
          const SizedBox(height: 10),
          Text(
            'Istirahat dan isi ulang',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Pilih rute di Jelajah, lalu ketuk titik pada peta untuk '
            'melihat perkiraan kebutuhan air, camilan, kopi, dan ban dalam.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          FilledButton.tonalIcon(
            onPressed: () => context.go('/routes'),
            icon: const Icon(Icons.map_outlined),
            label: const Text('Buka Jelajah'),
          ),
        ],
      ),
    ),
  );

  Widget _buildCurrencySection(BuildContext context, LogisticsState state) {
    final data = state.data;
    return SenapathCard(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Konversi mata uang',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pilih mata uang yang dipakai untuk menghitung biaya.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Perbarui nilai tukar',
                      onPressed: () =>
                          context.read<LogisticsCubit>().refreshRates(),
                      icon: const Icon(Icons.sync),
                    ),
                    IconButton(
                      tooltip: 'Atur kurs',
                      onPressed: () => _editRates(context, data),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              data.rateUpdatedAt == null
                  ? 'Nilai tukar belum tersedia. Coba perbarui atau masukkan sendiri.'
                  : data.rateSource == 'Frankfurter'
                  ? 'Nilai tukar harian · diperbarui ${_formatDateTime(data.rateUpdatedAt!.toLocal())}'
                  : 'Nilai tukar yang kamu masukkan · diperbarui ${_formatDateTime(data.rateUpdatedAt!.toLocal())}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (state.isRefreshingRates) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: 12),
            _buildBaseCurrencyConverter(context, data, state),
            if (state.isSaving)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetSection(BuildContext context, LogisticsState state) {
    final data = state.data;
    final allocated = BudgetCalculator.total(
      items: data.items,
      target: data.baseCurrency,
      eurRates: data.eurRates,
    );
    final spent = BudgetCalculator.expenseTotal(
      expenses: data.expenses,
      target: data.baseCurrency,
      eurRates: data.eurRates,
    );
    final remaining = allocated == null || spent == null
        ? null
        : allocated - spent;

    return SenapathCard(
      child: ExpansionTile(
        leading: const Icon(Icons.receipt_long_outlined),
        title: const Text('Anggaran'),
        initiallyExpanded: false,
        subtitle: Text(
          allocated == 0
              ? 'Buat rencana dan catat pengeluaran perjalanan.'
              : remaining == null
              ? 'Atur kurs untuk melihat sisa dalam ${data.baseCurrency.code} '
                    '(${data.baseCurrency.label}).'
              : 'Sisa ${_formatMoney(remaining, data.baseCurrency)} · '
                    'Terpakai ${_formatMoney(spent!, data.baseCurrency)}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: state.isSaving ? null : () => _editItem(context),
              icon: const Icon(Icons.add),
              label: const Text('Tambah item anggaran'),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Ringkasan menggunakan mata uang dasar ${data.baseCurrency.code} '
              '· ${data.baseCurrency.label}. '
              'Atur mata uang dasar di bagian Kurs & konversi mata uang. '
              'Nilai setara mengikuti kurs tersimpan.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 8),
          if (data.items.isNotEmpty) ...[
            _buildBudgetSummaryRow(
              context,
              'Total direncanakan',
              allocated,
              data.baseCurrency,
            ),
            _buildBudgetSummaryRow(
              context,
              'Total terpakai',
              spent,
              data.baseCurrency,
            ),
            _buildBudgetSummaryRow(
              context,
              remaining != null && remaining < 0
                  ? 'Melebihi anggaran'
                  : 'Sisa anggaran',
              remaining != null && remaining < 0 ? -remaining : remaining,
              data.baseCurrency,
              isEmphasized: true,
            ),
            const Divider(height: 20),
          ],
          if (data.items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Belum ada kategori. Buat kategori seperti makan, transportasi, '
                'akomodasi, atau perlengkapan.',
              ),
            )
          else
            for (final item in data.items)
              _buildBudgetItem(context, item, state),
          if (state.isSaving) const LinearProgressIndicator(),
        ],
      ),
    );
  }

  Widget _buildBudgetSummaryRow(
    BuildContext context,
    String label,
    double? amount,
    BudgetCurrency currency, {
    bool isEmphasized = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: isEmphasized ? Theme.of(context).textTheme.titleSmall : null,
          ),
        ),
        Text(
          amount == null
              ? 'Kurs belum lengkap'
              : _formatMoney(amount, currency),
          style: isEmphasized
              ? Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)
              : null,
        ),
      ],
    ),
  );

  Widget _buildBaseCurrencyConverter(
    BuildContext context,
    LogisticsData data,
    LogisticsState state,
  ) {
    final amount = _parseAmount(_eurAmountController.text);
    final destinationCurrencies = data.effectiveConversionCurrencies;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<BudgetCurrency>(
          key: const Key('logistics-base-currency'),
          initialValue: data.baseCurrency,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Mata uang dasar'),
          items: [
            for (final currency in BudgetCurrency.values)
              DropdownMenuItem(
                value: currency,
                child: CurrencyLabel(currency, dense: true),
              ),
          ],
          onChanged: state.isSaving
              ? null
              : (currency) {
                  if (currency != null) {
                    context.read<LogisticsCubit>().setBaseCurrency(currency);
                  }
                },
        ),
        const SizedBox(height: 6),
        TextField(
          key: const Key('eur-converter-amount'),
          controller: _eurAmountController,
          inputFormatters: [
            AmountInputFormatter(),
            ForbiddenCharactersInputFormatter(),
            LengthLimitingTextInputFormatter(20),
          ],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Nominal',
            prefixIcon: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(data.baseCurrency.code),
            ),
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        Text('Hasil konversi', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        if (amount == null || amount < 0)
          const Text('Masukkan nominal yang valid untuk melihat hasil.')
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final currency in destinationCurrencies)
                    SizedBox(
                      width: width,
                      child: _ConversionResult(
                        currency: currency,
                        result: _formatBaseConversion(
                          amount,
                          data.baseCurrency,
                          currency,
                          data,
                        ),
                        onRemove: state.isSaving
                            ? null
                            : () => context
                                  .read<LogisticsCubit>()
                                  .removeConversionCurrency(currency),
                      ),
                    ),
                ],
              );
            },
          ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed:
                state.isSaving || _remainingConversionCurrencies(data).isEmpty
                ? null
                : () => _addConversionCurrency(context, data),
            icon: const Icon(Icons.add),
            label: const Text('Tambah mata uang'),
          ),
        ),
      ],
    );
  }

  List<BudgetCurrency> _remainingConversionCurrencies(LogisticsData data) {
    final shown = data.effectiveConversionCurrencies.toSet();
    return [
      for (final currency in BudgetCurrency.values)
        if (currency != data.baseCurrency && !shown.contains(currency))
          currency,
    ];
  }

  Future<void> _addConversionCurrency(
    BuildContext context,
    LogisticsData data,
  ) async {
    final currency = await showDialog<BudgetCurrency>(
      context: context,
      builder: (_) => _ConversionCurrencyPickerDialog(
        available: _remainingConversionCurrencies(data),
      ),
    );
    if (currency != null && context.mounted) {
      await context.read<LogisticsCubit>().addConversionCurrency(currency);
    }
  }

  String _formatBaseConversion(
    double amount,
    BudgetCurrency baseCurrency,
    BudgetCurrency currency,
    LogisticsData data,
  ) {
    final converted = BudgetCalculator.convert(
      amount: amount,
      from: baseCurrency,
      to: currency,
      eurRates: data.eurRates,
    );
    if (converted == null) return '${currency.code} · atur kurs';
    return '${currency.code} ${_formatMoney(converted, currency)}';
  }

  Widget _buildBudgetItem(
    BuildContext context,
    BudgetItem item,
    LogisticsState state,
  ) {
    final data = state.data;
    final expenses =
        data.expenses
            .where((expense) => expense.budgetItemId == item.id)
            .toList()
          ..sort((left, right) => right.spentAt.compareTo(left.spentAt));
    final planned = BudgetCalculator.convert(
      amount: item.amount,
      from: item.currency,
      to: data.baseCurrency,
      eurRates: data.eurRates,
    );
    final spent = BudgetCalculator.expenseTotal(
      expenses: expenses,
      target: data.baseCurrency,
      eurRates: data.eurRates,
    );
    final remaining = planned == null || spent == null ? null : planned - spent;
    final progress = planned == null || spent == null || planned <= 0
        ? null
        : (spent / planned).clamp(0.0, 1.0);

    return SenapathCard(
      child: ExpansionTile(
        leading: const Icon(Icons.account_balance_wallet_outlined),
        title: Text(item.name),
        subtitle: Text(
          '${_formatMoney(item.amount, item.currency)} direncanakan'
          '${remaining == null || spent == null
              ? ''
              : remaining < 0
              ? '\nMelebihi ${_formatMoney(-remaining, data.baseCurrency)} · '
                    'terpakai ${_formatMoney(spent, data.baseCurrency)}'
              : '\nSisa ${_formatMoney(remaining, data.baseCurrency)} · '
                    'terpakai ${_formatMoney(spent, data.baseCurrency)}'}',
        ),
        trailing: Wrap(
          spacing: 0,
          children: [
            IconButton(
              tooltip: 'Edit ${item.name}',
              onPressed: state.isSaving ? null : () => _editItem(context, item),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Hapus ${item.name}',
              onPressed: state.isSaving
                  ? null
                  : () => _removeItem(context, item),
              icon: const Icon(Icons.delete_outline),
            ),
            const Icon(Icons.expand_more),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          if (planned == null || spent == null || remaining == null)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Kurs kategori atau pengeluaran belum tersedia. '
                'Perbarui kurs untuk menghitung sisa.',
              ),
            )
          else ...[
            LinearProgressIndicator(
              value: progress,
              color: remaining < 0 ? Theme.of(context).colorScheme.error : null,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                remaining < 0
                    ? 'Melebihi batas sebesar '
                          '${_formatMoney(-remaining, data.baseCurrency)}'
                    : 'Sisa ${_formatMoney(remaining, data.baseCurrency)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: remaining < 0
                      ? Theme.of(context).colorScheme.error
                      : null,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: state.isSaving
                  ? null
                  : () => _editExpense(context, item),
              icon: const Icon(Icons.add),
              label: const Text('Catat pengeluaran'),
            ),
          ),
          if (expenses.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Belum ada pengeluaran yang dicatat.'),
              ),
            )
          else
            for (final expense in expenses)
              _buildExpenseRow(context, item, expense, state),
        ],
      ),
    );
  }

  Widget _buildExpenseRow(
    BuildContext context,
    BudgetItem item,
    BudgetExpense expense,
    LogisticsState state,
  ) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.receipt_outlined),
    title: Text(
      expense.note.trim().isEmpty ? 'Pengeluaran' : expense.note,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    subtitle: Text(
      '${DateFormat('dd/MM/yyyy').format(expense.spentAt.toLocal())} · '
      '${_formatMoney(expense.amount, expense.currency)}',
    ),
    trailing: Wrap(
      spacing: 0,
      children: [
        IconButton(
          tooltip: 'Edit pengeluaran',
          onPressed: state.isSaving
              ? null
              : () => _editExpense(context, item, expense),
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          tooltip: 'Hapus pengeluaran',
          onPressed: state.isSaving
              ? null
              : () => _removeExpense(context, expense),
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    ),
  );

  Widget _buildTimeSection(BuildContext context) {
    final resolution = _timeConverter.resolveLocalTime(_eventTime, _sourceZone);
    final selectedInstant = resolution.isNonexistent
        ? null
        : resolution.isAmbiguous
        ? (_selectedOccurrence != null &&
                  _selectedOccurrence! < resolution.instants.length
              ? resolution.instants[_selectedOccurrence!]
              : null)
        : resolution.instants.single;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Waktu acara', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Zona waktu dasar / acara'),
          subtitle: Text('${_sourceZone.label} · ${_sourceZone.ianaName}'),
          trailing: const Icon(Icons.search),
          onTap: () async {
            final logisticsCubit = context.read<LogisticsCubit>();
            final zone = await _pickTimeZone();
            if (zone == null || !mounted) return;
            setState(() {
              _sourceZone = zone;
              _selectedOccurrence = null;
            });
            await logisticsCubit.setBaseTimeZone(zone.ianaName);
          },
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(_formatDate(_eventTime)),
            ),
            OutlinedButton.icon(
              onPressed: _pickTime,
              icon: const Icon(Icons.schedule),
              label: Text(_formatTime(_eventTime)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (resolution.isNonexistent)
          Text(
            'Jam ini tidak ada karena perubahan daylight saving. Pilih waktu lain.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (resolution.isAmbiguous) ...[
          const Text('Jam ini terjadi dua kali. Pilih salah satu kemunculan:'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (var index = 0; index < resolution.instants.length; index++)
                ChoiceChip(
                  label: Text(
                    '${index + 1} · ${_offsetLabel(resolution.instants[index].timeZone.offset)}',
                  ),
                  selected: _selectedOccurrence == index,
                  onSelected: (_) =>
                      setState(() => _selectedOccurrence = index),
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                'Waktu tujuan',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                final zone = await _pickTimeZone();
                if (zone == null ||
                    !mounted ||
                    _destinationZones.contains(zone)) {
                  return;
                }
                setState(
                  () => _destinationZones = [..._destinationZones, zone],
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Tambah zona'),
            ),
          ],
        ),
        for (final zone in _destinationZones)
          _buildConvertedTime(zone, selectedInstant),
      ],
    );
  }

  Widget _buildConvertedTime(EventTimeZone zone, DateTime? instant) {
    final converted = instant == null
        ? null
        : _timeConverter.convertInstant(instant, zone);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(zone.label),
      subtitle: Text(
        converted == null
            ? 'Pilih waktu valid untuk melihat hasil · ${zone.ianaName}'
            : '${_formatDate(converted)} · ${_formatTime(converted)} ${converted.timeZone.abbreviation} (${_offsetLabel(converted.timeZone.offset)}) · ${zone.ianaName}',
      ),
      trailing: _destinationZones.length < 2
          ? null
          : IconButton(
              tooltip: 'Hapus zona ${zone.label}',
              onPressed: () => setState(
                () => _destinationZones = _destinationZones
                    .where((destination) => destination != zone)
                    .toList(),
              ),
              icon: const Icon(Icons.close),
            ),
    );
  }

  Future<EventTimeZone?> _pickTimeZone() => showDialog<EventTimeZone>(
    context: context,
    builder: (_) => const _TimeZonePickerDialog(),
  );

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _eventTime,
      firstDate: DateTime(1970),
      lastDate: DateTime(2100),
    );
    if (date == null) return;
    setState(() {
      _eventTime = DateTime(
        date.year,
        date.month,
        date.day,
        _eventTime.hour,
        _eventTime.minute,
      );
      _selectedOccurrence = null;
    });
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_eventTime),
    );
    if (time == null) return;
    setState(() {
      _eventTime = DateTime(
        _eventTime.year,
        _eventTime.month,
        _eventTime.day,
        time.hour,
        time.minute,
      );
      _selectedOccurrence = null;
    });
  }

  Future<void> _editItem(BuildContext context, [BudgetItem? existing]) async {
    final item = await showDialog<BudgetItem>(
      context: context,
      builder: (_) => _BudgetItemDialog(
        existing: existing,
        defaultCurrency: context.read<LogisticsCubit>().state.data.baseCurrency,
      ),
    );
    if (item != null && context.mounted) {
      await context.read<LogisticsCubit>().upsertItem(item);
    }
  }

  Future<void> _editExpense(
    BuildContext context,
    BudgetItem item, [
    BudgetExpense? existing,
  ]) async {
    final expense = await showDialog<BudgetExpense>(
      context: context,
      builder: (_) =>
          _BudgetExpenseDialog(budgetItem: item, existing: existing),
    );
    if (expense != null && context.mounted) {
      await context.read<LogisticsCubit>().upsertExpense(expense);
    }
  }

  Future<void> _removeExpense(
    BuildContext context,
    BudgetExpense expense,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => SenapathAlertDialog(
        title: const Text('Hapus pengeluaran?'),
        content: const Text('Catatan pengeluaran ini akan dihapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<LogisticsCubit>().removeExpense(expense.id);
    }
  }

  Future<void> _editRates(BuildContext context, LogisticsData data) async {
    final rates = await showDialog<Map<BudgetCurrency, double>>(
      context: context,
      builder: (_) => _ExchangeRatesDialog(data: data),
    );
    if (rates != null && context.mounted) {
      await context.read<LogisticsCubit>().updateRates(rates);
    }
  }

  Future<void> _removeItem(BuildContext context, BudgetItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => SenapathAlertDialog(
        title: const Text('Hapus item?'),
        content: Text(
          '${item.name} dan seluruh catatan pengeluarannya akan dihapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<LogisticsCubit>().removeItem(item.id);
    }
  }

  String _formatMoney(double amount, BudgetCurrency currency) =>
      AmountInputFormatter.formatMoney(
        amount,
        currencyCode: currency.code,
        decimalDigits: currency.decimalDigits,
      );

  String _formatDate(DateTime date) {
    const weekdays = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatTime(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  String _formatDateTime(DateTime date) =>
      '${_formatDate(date)} ${_formatTime(date)}';

  String _offsetLabel(Duration offset) {
    final totalMinutes = offset.inMinutes;
    final sign = totalMinutes < 0 ? '-' : '+';
    final absoluteMinutes = totalMinutes.abs();
    final hours = (absoluteMinutes ~/ 60).toString().padLeft(2, '0');
    final minutes = (absoluteMinutes % 60).toString().padLeft(2, '0');
    return 'UTC$sign$hours:$minutes';
  }
}

class _ConversionResult extends StatelessWidget {
  const _ConversionResult({
    required this.currency,
    required this.result,
    this.onRemove,
  });

  final BudgetCurrency currency;
  final String result;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 84),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                currency.code,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (onRemove != null)
              SizedBox(
                width: 22,
                height: 22,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 16,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Hapus ${currency.code}',
                  onPressed: onRemove,
                  icon: const Icon(Icons.close),
                ),
              ),
          ],
        ),
        Text(
          currency.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Text(
          result,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _ConversionCurrencyPickerDialog extends StatelessWidget {
  const _ConversionCurrencyPickerDialog({required this.available});

  final List<BudgetCurrency> available;

  @override
  Widget build(BuildContext context) => SenapathAlertDialog(
    title: const Text('Tambah mata uang'),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: available.isEmpty
                  ? const Center(
                      child: Text('Semua mata uang sudah ditampilkan.'),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: available.length,
                      itemBuilder: (context, index) {
                        final currency = available[index];
                        return ListTile(
                          dense: true,
                          title: CurrencyLabel(currency),
                          onTap: () => Navigator.of(context).pop(currency),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Batal'),
      ),
    ],
  );
}

class _TimeZonePickerDialog extends StatefulWidget {
  const _TimeZonePickerDialog();

  @override
  State<_TimeZonePickerDialog> createState() => _TimeZonePickerDialogState();
}

class _TimeZonePickerDialogState extends State<_TimeZonePickerDialog> {
  final _searchController = TextEditingController();
  late final List<EventTimeZone> _zones = EventTimeZone.all;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final matches = _zones
        .where((zone) {
          return query.isEmpty ||
              zone.label.toLowerCase().contains(query) ||
              zone.ianaName.toLowerCase().contains(query);
        })
        .toList(growable: false);

    return SenapathAlertDialog(
      title: const Text('Pilih zona waktu'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              autofocus: true,
              inputFormatters: [
                const SingleLineInputFormatter(),
                const ForbiddenCharactersInputFormatter(),
                LengthLimitingTextInputFormatter(
                  InputLimits.searchQueryMaxLength,
                ),
              ],
              decoration: const InputDecoration(
                labelText: 'Cari kota atau zona',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: matches.isEmpty
                    ? const Center(child: Text('Zona waktu tidak ditemukan.'))
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: matches.length,
                        itemBuilder: (context, index) {
                          final zone = matches[index];
                          return ListTile(
                            dense: true,
                            title: Text(zone.label),
                            subtitle: Text(zone.ianaName),
                            onTap: () => Navigator.of(context).pop(zone),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
      ],
    );
  }
}

class _BudgetItemDialog extends StatefulWidget {
  const _BudgetItemDialog({required this.defaultCurrency, this.existing});

  final BudgetItem? existing;
  final BudgetCurrency defaultCurrency;

  @override
  State<_BudgetItemDialog> createState() => _BudgetItemDialogState();
}

class _BudgetItemDialogState extends State<_BudgetItemDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  final _formKey = GlobalKey<FormState>();
  late BudgetCurrency _currency;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _amountController = TextEditingController(
      text: widget.existing == null
          ? ''
          : AmountInputFormatter.formatValue(widget.existing!.amount),
    );
    _currency = widget.existing?.currency ?? widget.defaultCurrency;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SenapathAlertDialog(
    scrollable: true,
    title: Text(widget.existing == null ? 'Tambah anggaran' : 'Edit anggaran'),
    content: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _nameController,
            inputFormatters: [
              const SingleLineInputFormatter(),
              const ForbiddenCharactersInputFormatter(),
              LengthLimitingTextInputFormatter(InputLimits.itemNameMaxLength),
            ],
            decoration: const InputDecoration(labelText: 'Nama item'),
            validator: (value) => TextValidators.name(
              value,
              label: 'nama item',
              maxLength: InputLimits.itemNameMaxLength,
              emptyMessage: 'Isi nama item.',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _amountController,
            inputFormatters: [
              AmountInputFormatter(),
              ForbiddenCharactersInputFormatter(),
              LengthLimitingTextInputFormatter(20),
            ],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Nominal'),
            validator: (value) => AmountValidators.amount(
              value,
              label: 'nominal',
              parsed: _parseAmount(value),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<BudgetCurrency>(
            initialValue: _currency,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Mata uang'),
            items: [
              for (final currency in BudgetCurrency.values)
                DropdownMenuItem(
                  value: currency,
                  child: CurrencyLabel(currency, dense: true),
                ),
            ],
            onChanged: (currency) {
              if (currency != null) setState(() => _currency = currency);
            },
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(
            context,
            BudgetItem(
              id:
                  widget.existing?.id ??
                  DateTime.now().microsecondsSinceEpoch.toString(),
              name: _nameController.text.trim(),
              amount: _parseAmount(_amountController.text)!,
              currency: _currency,
            ),
          );
        },
        child: const Text('Simpan'),
      ),
    ],
  );
}

class _BudgetExpenseDialog extends StatefulWidget {
  const _BudgetExpenseDialog({required this.budgetItem, this.existing});

  final BudgetItem budgetItem;
  final BudgetExpense? existing;

  @override
  State<_BudgetExpenseDialog> createState() => _BudgetExpenseDialogState();
}

class _BudgetExpenseDialogState extends State<_BudgetExpenseDialog> {
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  final _formKey = GlobalKey<FormState>();
  late BudgetCurrency _currency;
  late DateTime _spentAt;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.existing == null
          ? ''
          : AmountInputFormatter.formatValue(widget.existing!.amount),
    );
    _noteController = TextEditingController(text: widget.existing?.note ?? '');
    _currency = widget.existing?.currency ?? widget.budgetItem.currency;
    _spentAt = widget.existing?.spentAt.toLocal() ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _spentAt,
      firstDate: DateTime(1970),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (selected != null) {
      setState(() {
        _spentAt = DateTime(
          selected.year,
          selected.month,
          selected.day,
          _spentAt.hour,
          _spentAt.minute,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) => SenapathAlertDialog(
    title: Text(
      widget.existing == null ? 'Catat pengeluaran' : 'Edit pengeluaran',
    ),
    content: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _amountController,
              inputFormatters: [
                AmountInputFormatter(),
                ForbiddenCharactersInputFormatter(),
                LengthLimitingTextInputFormatter(20),
              ],
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Nominal yang dibayar',
              ),
              validator: (value) => AmountValidators.amount(
                value,
                label: 'nominal',
                parsed: _parseAmount(value),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<BudgetCurrency>(
              initialValue: _currency,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Mata uang bayar'),
              items: [
                for (final currency in BudgetCurrency.values)
                  DropdownMenuItem(
                    value: currency,
                    child: CurrencyLabel(currency, dense: true),
                  ),
              ],
              onChanged: (currency) {
                if (currency != null) setState(() => _currency = currency);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteController,
              inputFormatters: [
                const SingleLineInputFormatter(),
                const ForbiddenCharactersInputFormatter(),
                LengthLimitingTextInputFormatter(
                  InputLimits.expenseNoteMaxLength,
                ),
              ],
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
                hintText: 'Contoh: makan siang',
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (value) => TextValidators.optionalText(
                value,
                label: 'catatan',
                maxLength: InputLimits.expenseNoteMaxLength,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(DateFormat('dd/MM/yyyy').format(_spentAt)),
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(
            context,
            BudgetExpense(
              id:
                  widget.existing?.id ??
                  DateTime.now().microsecondsSinceEpoch.toString(),
              budgetItemId: widget.budgetItem.id,
              amount: _parseAmount(_amountController.text)!,
              currency: _currency,
              spentAt: _spentAt,
              note: _noteController.text.trim(),
            ),
          );
        },
        child: const Text('Simpan'),
      ),
    ],
  );
}

class _ExchangeRatesDialog extends StatefulWidget {
  const _ExchangeRatesDialog({required this.data});

  final LogisticsData data;

  @override
  State<_ExchangeRatesDialog> createState() => _ExchangeRatesDialogState();
}

class _ExchangeRatesDialogState extends State<_ExchangeRatesDialog> {
  final _formKey = GlobalKey<FormState>();
  late final Map<BudgetCurrency, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final currency in BudgetCurrency.values)
        if (currency != BudgetCurrency.eur)
          currency: TextEditingController(
            text: widget.data.eurRates[currency] == null
                ? ''
                : AmountInputFormatter.formatValue(
                    widget.data.eurRates[currency]!,
                  ),
          ),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SenapathAlertDialog(
    title: const Text('Kurs manual'),
    content: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Masukkan nilai mata uang yang ingin diatur untuk 1 EUR. '
              'Kurs yang dikosongkan tidak akan diubah.',
            ),
            for (final currency in _controllers.keys) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _controllers[currency],
                inputFormatters: [
                  AmountInputFormatter(),
                  ForbiddenCharactersInputFormatter(),
                  LengthLimitingTextInputFormatter(20),
                ],
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: '1 EUR = ... ${currency.code} · ${currency.label}',
                ),
                validator: (value) => AmountValidators.amount(
                  value,
                  label: 'kurs',
                  parsed: _parseAmount(value),
                  required: false,
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Sumber: input manual. Kurs ini tidak diperbarui otomatis dan bukan kurs real-time.',
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          final rates = <BudgetCurrency, double>{
            for (final entry in _controllers.entries)
              if (entry.value.text.trim().isNotEmpty)
                entry.key: _parseAmount(entry.value.text)!,
          };
          if (rates.isNotEmpty) Navigator.pop(context, rates);
        },
        child: const Text('Simpan kurs'),
      ),
    ],
  );
}

double? _parseAmount(String? value) => AmountInputFormatter.parse(value);
