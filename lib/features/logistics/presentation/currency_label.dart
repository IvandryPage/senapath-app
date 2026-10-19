import 'package:flutter/material.dart';

import '../domain/logistics_models.dart';

/// Shows a currency code together with its readable name, e.g.
/// "MYR  Ringgit Malaysia".
class CurrencyLabel extends StatelessWidget {
  const CurrencyLabel(this.currency, {this.dense = false, super.key});

  final BudgetCurrency currency;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          currency.code,
          style:
              (dense ? theme.textTheme.bodyMedium : theme.textTheme.bodyLarge)
                  ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            currency.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                (dense ? theme.textTheme.bodySmall : theme.textTheme.bodyMedium)
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
