import 'package:flutter/material.dart';

enum FeatureStateKind { loading, empty, error }

class FeatureStateView extends StatelessWidget {
  const FeatureStateView.loading({super.key, this.message = 'Memuat data...'})
    : kind = FeatureStateKind.loading,
      title = '',
      icon = Icons.hourglass_empty,
      actionLabel = null,
      onAction = null;

  const FeatureStateView.empty({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.actionLabel,
    this.onAction,
  }) : kind = FeatureStateKind.empty;

  const FeatureStateView.error({
    super.key,
    this.title = 'Terjadi kendala',
    required this.message,
    this.actionLabel = 'Coba lagi',
    this.onAction,
  }) : kind = FeatureStateKind.error,
       icon = Icons.cloud_off_outlined;

  final FeatureStateKind kind;
  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    if (kind == FeatureStateKind.loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 20),
                FilledButton.tonal(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
