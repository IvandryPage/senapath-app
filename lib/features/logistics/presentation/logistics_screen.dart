import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/senapath_design.dart';
import '../domain/event_time_converter.dart';
import '../domain/logistics_models.dart';
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
  EventTimeZone _sourceZone = EventTimeZone.centralEurope;
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
    unawaited(context.read<LogisticsCubit>().load());
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
                // Budget section first — keeps 'Tambah item anggaran' near the top
                _buildBudgetSection(context, state),
                const SizedBox(height: 18),
                _buildCurrencySection(context, state),
                const SizedBox(height: 20),
                _buildTimeSection(context),
              ],
            ),
          );
        },
      ),
    );
  }

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
                        'Masukkan EUR untuk melihat nilai dalam IDR, USD, dan CHF.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Ambil kurs referensi',
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
                  ? 'Kurs belum tersedia. Ambil kurs referensi atau atur manual.'
                  : data.rateSource == 'Frankfurter'
                  ? 'Kurs referensi harian · Frankfurter · diperbarui ${_formatDateTime(data.rateUpdatedAt!.toLocal())}'
                  : 'Kurs manual · diperbarui ${_formatDateTime(data.rateUpdatedAt!.toLocal())} · bukan real-time',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (state.isRefreshingRates) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: 12),
            _buildEurConverter(context, data),
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
    final total = BudgetCalculator.total(
      items: data.items,
      target: data.targetCurrency,
      eurRates: data.eurRates,
    );

    return SenapathCard(
      child: ExpansionTile(
        leading: const Icon(Icons.receipt_long_outlined),
        title: const Text('Anggaran'),
        initiallyExpanded: true,
        subtitle: Text(
          total == null
              ? 'Tambahkan biaya perjalanan dan pilih mata uang total.'
              : 'Total saat ini ${_formatMoney(total, data.targetCurrency)}',
        ),
        trailing: Tooltip(
          message: 'Tambah item anggaran',
          child: IconButton(
            onPressed: state.isSaving ? null : () => _editItem(context),
            icon: const Icon(Icons.add),
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
        DropdownButtonFormField<BudgetCurrency>(
          initialValue: data.targetCurrency,
          decoration: const InputDecoration(labelText: 'Total dalam'),
          items: [
            for (final currency in BudgetCurrency.values)
              DropdownMenuItem(value: currency, child: Text(currency.code)),
          ],
          onChanged: state.isSaving
              ? null
              : (currency) {
                  if (currency != null) {
                    context.read<LogisticsCubit>().setTargetCurrency(currency);
                  }
                },
        ),
        const SizedBox(height: 12),
        if (data.items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Belum ada item anggaran.'),
          )
        else
          for (final item in data.items) _buildBudgetItem(context, item, state),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                'Total',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              total == null
                  ? 'Kurs belum lengkap'
                  : _formatMoney(total, data.targetCurrency),
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        if (state.isSaving) const LinearProgressIndicator(),
      ],
      ),
    );
  }

  Widget _buildEurConverter(BuildContext context, LogisticsData data) {
    final amount = _parseAmount(_eurAmountController.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Dari', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        TextField(
          key: const Key('eur-converter-amount'),
          controller: _eurAmountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Nominal dalam EUR',
            prefixIcon: Padding(
              padding: EdgeInsets.all(14),
              child: Text('EUR'),
            ),
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        Text('Hasil konversi', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        if (amount == null || amount < 0)
          const Text('Masukkan nominal EUR yang valid untuk melihat hasil.')
        else
          Row(
            children: [
              for (final currency in [
                BudgetCurrency.idr,
                BudgetCurrency.usd,
                BudgetCurrency.chf,
              ])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _ConversionResult(
                      currency: currency,
                      result: _formatEurConversion(amount, currency, data),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  String _formatEurConversion(
    double amount,
    BudgetCurrency currency,
    LogisticsData data,
  ) {
    final converted = BudgetCalculator.convert(
      amount: amount,
      from: BudgetCurrency.eur,
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
  ) => SenapathCard(
    child: ListTile(
      title: Text(item.name),
      subtitle: Text(_formatMoney(item.amount, item.currency)),
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
            onPressed: state.isSaving ? null : () => _removeItem(context, item),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
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
          title: const Text('Zona waktu sumber'),
          subtitle: Text('${_sourceZone.label} · ${_sourceZone.ianaName}'),
          trailing: const Icon(Icons.search),
          onTap: () async {
            final zone = await _pickTimeZone();
            if (zone == null || !mounted) return;
            setState(() {
              _sourceZone = zone;
              _selectedOccurrence = null;
            });
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
      builder: (_) => _BudgetItemDialog(existing: existing),
    );
    if (item != null && context.mounted) {
      await context.read<LogisticsCubit>().upsertItem(item);
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
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus item?'),
        content: Text('${item.name} akan dihapus dari anggaran.'),
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
      NumberFormat.currency(
        name: currency.code,
        decimalDigits: currency == BudgetCurrency.idr ? 0 : 2,
      ).format(amount);

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
  const _ConversionResult({required this.currency, required this.result});

  final BudgetCurrency currency;
  final String result;

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
        Text(
          currency.code,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          result,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
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

    return AlertDialog(
      title: const Text('Pilih zona waktu'),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Cari kota atau zona',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: matches.isEmpty
                  ? const Center(child: Text('Zona waktu tidak ditemukan.'))
                  : ListView.builder(
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
  const _BudgetItemDialog({this.existing});

  final BudgetItem? existing;

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
          : _decimalText(widget.existing!.amount),
    );
    _currency = widget.existing?.currency ?? BudgetCurrency.eur;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.existing == null ? 'Tambah anggaran' : 'Edit anggaran'),
    content: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Nama item'),
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Isi nama item.' : null,
          ),
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Nominal'),
            validator: (value) {
              final amount = _parseAmount(value);
              return amount == null || amount <= 0
                  ? 'Masukkan nominal lebih dari nol.'
                  : null;
            },
          ),
          DropdownButtonFormField<BudgetCurrency>(
            initialValue: _currency,
            decoration: const InputDecoration(labelText: 'Mata uang'),
            items: [
              for (final currency in BudgetCurrency.values)
                DropdownMenuItem(value: currency, child: Text(currency.code)),
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
                : _decimalText(widget.data.eurRates[currency]!),
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
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Kurs manual'),
    content: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Masukkan nilai setiap mata uang untuk 1 EUR.'),
            for (final currency in _controllers.keys)
              TextFormField(
                controller: _controllers[currency],
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: '1 EUR = ... ${currency.code}',
                ),
                validator: (value) {
                  final rate = _parseAmount(value);
                  return rate == null || rate <= 0
                      ? 'Masukkan kurs lebih dari nol.'
                      : null;
                },
              ),
            const SizedBox(height: 8),
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
          Navigator.pop(context, {
            for (final currency in _controllers.keys)
              currency: _parseAmount(_controllers[currency]!.text)!,
          });
        },
        child: const Text('Simpan kurs'),
      ),
    ],
  );
}

String _decimalText(double amount) => amount
    .toStringAsFixed(6)
    .replaceFirst(RegExp(r'0+$'), '')
    .replaceFirst(RegExp(r'\.$'), '');

double? _parseAmount(String? value) =>
    double.tryParse(value?.trim().replaceAll(',', '.') ?? '');
