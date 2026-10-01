import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

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

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              _buildBudgetSection(context, state),
              const SizedBox(height: 28),
              const Divider(),
              const SizedBox(height: 16),
              _buildTimeSection(context),
            ],
          );
        },
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Anggaran',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: 'Atur kurs',
              onPressed: state.isSaving
                  ? null
                  : () => _editRates(context, data),
              icon: const Icon(Icons.currency_exchange),
            ),
            IconButton(
              tooltip: 'Tambah item anggaran',
              onPressed: state.isSaving ? null : () => _editItem(context),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        Text(
          data.rateUpdatedAt == null
              ? 'Kurs belum diatur. Masukkan kurs manual untuk membandingkan mata uang.'
              : 'Kurs manual · diperbarui ${_formatDateTime(data.rateUpdatedAt!.toLocal())} · bukan real-time',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        _buildEurConverter(context, data),
        const SizedBox(height: 12),
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
    );
  }

  Widget _buildEurConverter(BuildContext context, LogisticsData data) {
    final amount = _parseAmount(_eurAmountController.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Konversi EUR', style: Theme.of(context).textTheme.titleMedium),
        TextField(
          key: const Key('eur-converter-amount'),
          controller: _eurAmountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Nominal',
            prefixText: 'EUR ',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        if (amount == null || amount < 0)
          const Text('Masukkan nominal EUR yang valid.')
        else
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              for (final currency in [
                BudgetCurrency.idr,
                BudgetCurrency.usd,
                BudgetCurrency.chf,
              ])
                Text(_formatEurConversion(amount, currency, data)),
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
  ) => Card(
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
        DropdownButtonFormField<EventTimeZone>(
          initialValue: _sourceZone,
          decoration: const InputDecoration(labelText: 'Zona waktu sumber'),
          items: [
            for (final zone in EventTimeZone.values)
              DropdownMenuItem(value: zone, child: Text(zone.label)),
          ],
          onChanged: (zone) {
            if (zone == null) return;
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
        if (selectedInstant != null) ...[
          const SizedBox(height: 12),
          for (final zone in EventTimeZone.destinations)
            _buildConvertedTime(zone, selectedInstant),
        ],
      ],
    );
  }

  Widget _buildConvertedTime(EventTimeZone zone, DateTime instant) {
    final converted = _timeConverter.convertInstant(instant, zone);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(zone.label),
      subtitle: Text(
        '${_formatDate(converted)} · ${_formatTime(converted)} ${converted.timeZone.abbreviation} (${_offsetLabel(converted.timeZone.offset)})',
      ),
    );
  }

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
