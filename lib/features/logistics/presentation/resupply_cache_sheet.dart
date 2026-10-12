import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/senapath_design.dart';
import '../../routes/domain/saved_route.dart';
import '../domain/logistics_models.dart';
import 'logistics_cubit.dart';

class ResupplyCacheSheet extends StatefulWidget {
  const ResupplyCacheSheet({
    required this.routeName,
    required this.checkpoint,
    super.key,
  });

  final String routeName;
  final RouteCheckpoint checkpoint;

  @override
  State<ResupplyCacheSheet> createState() => _ResupplyCacheSheetState();
}

class _ResupplyCacheSheetState extends State<ResupplyCacheSheet> {
  BudgetCurrency _localCurrency = BudgetCurrency.idr;
  String? _selectedItemId;
  final _areaHintController = TextEditingController();
  bool _isEstimating = false;
  String? _estimateError;
  List<ResupplyPriceEstimate> _estimates = const [];
  int _estimateRequestId = 0;

  static const _suggestedItems = <_ResupplyItem>[
    _ResupplyItem(
      id: 'water',
      label: 'Air minum 1,5 L',
      icon: Icons.water_drop_outlined,
    ),
    _ResupplyItem(
      id: 'electrolyte',
      label: 'Minuman elektrolit',
      icon: Icons.bolt_outlined,
    ),
    _ResupplyItem(
      id: 'banana',
      label: 'Pisang / buah',
      icon: Icons.bakery_dining_outlined,
    ),
    _ResupplyItem(
      id: 'energy-snack',
      label: 'Snack energi',
      icon: Icons.cookie_outlined,
    ),
    _ResupplyItem(
      id: 'meal',
      label: 'Makan / nasi bungkus',
      icon: Icons.restaurant_outlined,
    ),
    _ResupplyItem(
      id: 'coffee',
      label: 'Kopi',
      icon: Icons.coffee_outlined,
    ),
    _ResupplyItem(id: 'tube', label: 'Ban dalam', icon: Icons.tire_repair),
    _ResupplyItem(
      id: 'patch-kit',
      label: 'Tambal ban',
      icon: Icons.build_outlined,
    ),
    _ResupplyItem(
      id: 'co2-pump',
      label: 'CO₂ / pompa mini',
      icon: Icons.air_outlined,
    ),
    _ResupplyItem(
      id: 'sunscreen',
      label: 'Tabir surya',
      icon: Icons.wb_sunny_outlined,
    ),
    _ResupplyItem(
      id: 'basic-medicine',
      label: 'Obat pribadi',
      icon: Icons.medication_outlined,
    ),
  ];

  List<_ResupplyItem> _items(LogisticsData data) => [
    ..._suggestedItems,
    for (final item in data.customResupplyItems)
      _ResupplyItem(
        id: item.id,
        label: item.name,
        icon: Icons.inventory_2_outlined,
        isCustom: true,
      ),
  ];

  @override
  void dispose() {
    _areaHintController.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<LogisticsCubit, LogisticsState>(
    builder: (context, state) {
      final colors = Theme.of(context).colorScheme;
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.checkpoint.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.routeName} · titik resupply dari GPX',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup checkpoint',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Estimasi kebutuhan',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<BudgetCurrency>(
                initialValue: _localCurrency,
                decoration: const InputDecoration(
                  labelText: 'Mata uang harga lokal',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                items: [
                  for (final currency in BudgetCurrency.values)
                    DropdownMenuItem(
                      value: currency,
                      child: Text(currency.code),
                    ),
                ],
                onChanged: (currency) {
                  if (currency != null) {
                    setState(() {
                      _localCurrency = currency;
                      _estimates = const [];
                      _estimateError = null;
                    });
                    final selectedId = _selectedItemId;
                    if (selectedId != null) {
                      final selectedItem = _items(state.data).firstWhere(
                        (item) => item.id == selectedId,
                      );
                      _requestEstimate(context, selectedItem, state);
                    }
                  }
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Mata uang pembanding: ${state.data.baseCurrency.code} '
                '(bisa diubah di menu Logistik)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _areaHintController,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Negara/kota (opsional)',
                  helperText:
                      'Dikirim ke layanan AI untuk memperkirakan harga; '
                      'koordinat GPS tidak dikirim.',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Barang resupply',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addCustomItem,
                    icon: const Icon(Icons.add),
                    label: const Text('Tambah barang'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.3,
                children: [
                  for (final item in _items(state.data))
                    _buildItemCard(context, item, state),
                ],
              ),
              if (_selectedItemId case final selectedId?) ...[
                const SizedBox(height: 12),
                _buildSelectedEstimate(context, selectedId, state),
              ],
              const SizedBox(height: 8),
              Text(
                'Estimasi AI non-real-time bersifat indikatif dan bukan harga '
                'terverifikasi toko. Saat memilih barang, nama barang, mata uang, '
                'dan wilayah opsional dikirim ke layanan AI; koordinat GPS '
                'tidak dikirim.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (state.data.eurRates[BudgetCurrency.idr] == null ||
                  state.data.eurRates[_localCurrency] == null ||
                  !state.isLoaded) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: state.isLoading || state.isRefreshingRates
                      ? null
                      : () {
                          final cubit = context.read<LogisticsCubit>();
                          if (state.isLoaded) {
                            cubit.refreshRates();
                          } else {
                            cubit.load();
                          }
                        },
                  icon: state.isRefreshingRates
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.currency_exchange),
                  label: Text(
                    state.isLoaded
                        ? 'Muat kurs referensi'
                        : 'Coba muat data logistik',
                  ),
                ),
              ],
              if (state.error != null) ...[
                const SizedBox(height: 8),
                Text(
                  state.error!,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.error),
                ),
              ],
              if (state.data.rateUpdatedAt case final rateUpdatedAt?) ...[
                const SizedBox(height: 6),
                Text(
                  'Kurs ${state.data.rateSource} · ${DateFormat('d MMM yyyy').format(rateUpdatedAt.toLocal())}',
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );

  Widget _buildItemCard(
    BuildContext context,
    _ResupplyItem item,
    LogisticsState state,
  ) {
    final selected = item.id == _selectedItemId;
    final estimate = _estimateFor(item.id);
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() {
            _selectedItemId = item.id;
            _estimates = _estimates
                .where((estimate) => estimate.itemId != item.id)
                .toList();
            _estimateError = null;
          });
          _requestEstimate(context, item, state);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    item.icon,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const Spacer(),
                  if (item.isCustom)
                    IconButton(
                      tooltip: 'Hapus ${item.label}',
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(
                        width: 32,
                        height: 32,
                      ),
                      onPressed: () {
                        setState(() {
                          _estimates = _estimates
                              .where((estimate) => estimate.itemId != item.id)
                              .toList();
                          if (_selectedItemId == item.id) {
                            _selectedItemId = null;
                            _isEstimating = false;
                            _estimateRequestId++;
                          }
                        });
                        _removeCustomItem(context, item);
                      },
                      icon: const Icon(Icons.close, size: 18),
                    ),
                ],
              ),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              Text(
                _isEstimating && selected
                    ? 'Meminta estimasi…'
                    : estimate == null
                    ? selected && _estimateError != null
                          ? 'Estimasi gagal'
                          : 'Ketuk untuk estimasi'
                    : _formatEstimate(estimate, state.data),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedEstimate(
    BuildContext context,
    String selectedId,
    LogisticsState state,
  ) {
    final item = _items(state.data).firstWhere(
      (item) => item.id == selectedId,
    );
    final estimate = _estimateFor(item.id);
    if (estimate == null && !_isEstimating && _estimateError == null) {
      return const SizedBox.shrink();
    }
    return SenapathCard(
      child: ListTile(
        leading: _isEstimating
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(item.icon),
        title: Text(item.label),
        subtitle: Text(
          estimate != null
              ? _formatEstimate(estimate, state.data)
              : _estimateError ?? 'Mengambil kisaran harga indikatif dari AI…',
        ),
        trailing: _estimateError == null
            ? null
            : IconButton(
                tooltip: 'Coba estimasi lagi',
                onPressed: _isEstimating
                    ? null
                    : () => _requestEstimate(context, item, state),
                icon: const Icon(Icons.refresh),
              ),
      ),
    );
  }

  Future<void> _requestEstimate(
    BuildContext context,
    _ResupplyItem item,
    LogisticsState state,
  ) async {
    final requestId = ++_estimateRequestId;
    setState(() {
      _isEstimating = true;
      _estimateError = null;
    });
    try {
      final estimates = await context
          .read<LogisticsCubit>()
          .estimateResupplyPrices(
            items: {item.id: item.label},
            localCurrency: _localCurrency,
            baseCurrency: state.data.baseCurrency,
            areaHint: _areaHintController.text,
          );
      if (!mounted || requestId != _estimateRequestId) return;
      setState(() {
        _estimates = [
          ..._estimates.where((estimate) => estimate.itemId != item.id),
          ...estimates,
        ];
        _isEstimating = false;
      });
    } catch (error) {
      if (!mounted || requestId != _estimateRequestId) return;
      setState(() {
        _isEstimating = false;
        _estimateError = error is StateError
            ? error.message
            : 'Estimasi gagal: $error';
      });
    }
  }

  Future<void> _addCustomItem() async {
    final label = await showDialog<String>(
      context: context,
      builder: (_) => const _CustomResupplyItemDialog(),
    );
    if (label == null || !mounted) return;
    await context.read<LogisticsCubit>().upsertCustomResupplyItem(
      CustomResupplyItem(
        id: 'custom-${DateTime.now().microsecondsSinceEpoch}',
        name: label,
      ),
    );
  }

  Future<void> _removeCustomItem(
    BuildContext context,
    _ResupplyItem item,
  ) async {
    await context.read<LogisticsCubit>().removeCustomResupplyItem(item.id);
  }

  ResupplyPriceEstimate? _estimateFor(String itemId) {
    for (final estimate in _estimates) {
      if (estimate.itemId == itemId) return estimate;
    }
    return null;
  }

  String _formatEstimate(ResupplyPriceEstimate estimate, LogisticsData data) {
    final local =
        '${_formatMoney(estimate.low, estimate.currency)} – '
        '${_formatMoney(estimate.high, estimate.currency)}';
    final lowBase = BudgetCalculator.convert(
      amount: estimate.low,
      from: estimate.currency,
      to: data.baseCurrency,
      eurRates: data.eurRates,
    );
    final highBase = BudgetCalculator.convert(
      amount: estimate.high,
      from: estimate.currency,
      to: data.baseCurrency,
      eurRates: data.eurRates,
    );
    if (lowBase == null || highBase == null) {
      return '$local · kurs ${data.baseCurrency.code} belum tersedia';
    }
    return '$local ≈ ${_formatMoney(lowBase, data.baseCurrency)} – '
        '${_formatMoney(highBase, data.baseCurrency)}';
  }

  String _formatMoney(double amount, BudgetCurrency currency) =>
      NumberFormat.currency(
        name: currency.code,
        symbol: '${currency.code} ',
        decimalDigits: currency.decimalDigits,
      ).format(amount);
}

class _ResupplyItem {
  const _ResupplyItem({
    required this.id,
    required this.label,
    required this.icon,
    this.isCustom = false,
  });

  final String id;
  final String label;
  final IconData icon;
  final bool isCustom;
}

class _CustomResupplyItemDialog extends StatefulWidget {
  const _CustomResupplyItemDialog();

  @override
  State<_CustomResupplyItemDialog> createState() =>
      _CustomResupplyItemDialogState();
}

class _CustomResupplyItemDialogState extends State<_CustomResupplyItemDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SenapathAlertDialog(
    title: const Text('Tambah barang resupply'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLength: 60,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        labelText: 'Nama barang',
        hintText: 'Contoh: roti isi atau baterai lampu',
      ),
      onSubmitted: (value) {
        final label = value.trim();
        if (label.isNotEmpty) Navigator.pop(context, label);
      },
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        onPressed: () {
          final label = _controller.text.trim();
          if (label.isNotEmpty) Navigator.pop(context, label);
        },
        child: const Text('Tambah'),
      ),
    ],
  );
}
