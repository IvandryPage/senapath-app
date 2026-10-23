import 'package:flutter/material.dart';

import '../../core/widgets/press_scale.dart';

abstract final class SenapathColors {
  static const navy = Color(0xFF0C3156);
  static const blue = Color(0xFF0A7DD2);
  static const accent = Color(0xFF99D0EC);
  static const pale = Color(0xFFDDF3FE);
  static const white = Color(0xFFFFFFFF);
  static const ink = Color(0xFF071122);
  static const canvas = pale;
}

abstract final class SenapathSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

class SenapathAlertDialog extends StatelessWidget {
  /// Membuat dialog peringatan dengan padding dan opsi gulir yang dapat diatur.
  const SenapathAlertDialog({
    this.title,
    this.content,
    this.actions,
    this.contentPadding = const EdgeInsets.fromLTRB(24, 16, 24, 8),
    this.titlePadding = const EdgeInsets.fromLTRB(24, 24, 24, 0),
    this.actionsPadding = const EdgeInsets.fromLTRB(16, 8, 16, 16),
    this.scrollable = false,
    super.key,
  });

  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final EdgeInsetsGeometry contentPadding;
  final EdgeInsetsGeometry titlePadding;
  final EdgeInsetsGeometry actionsPadding;
  final bool scrollable;

  /// Menampilkan konten dialog memakai AlertDialog yang sudah ditata.
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: title,
    content: content,
    actions: actions,
    titlePadding: titlePadding,
    contentPadding: contentPadding,
    actionsPadding: actionsPadding,
    scrollable: scrollable,
    actionsOverflowButtonSpacing: SenapathSpacing.xs,
  );
}

abstract final class SenapathShape {
  static const small = 8.0;
  static const medium = 12.0;
  static const large = 16.0;
  static const borderWidth = 1.0;
}

class SenapathCard extends StatelessWidget {
  /// Membuat kartu dengan sudut membulat, garis tepi, dan aksi ketuk opsional.
  const SenapathCard({
    required this.child,
    this.onTap,
    this.padding = EdgeInsets.zero,
    this.margin = const EdgeInsets.symmetric(vertical: 6),
    this.color,
    this.clipBehavior = Clip.none,
    this.borderRadius = SenapathShape.medium,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? color;
  final Clip clipBehavior;
  final double borderRadius;

  /// Membangun kartu bertema berisi child dan area ketuk yang memberi efek
  /// ripple.
  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final colors = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(borderRadius);
    return Card(
      color: color ?? surface,
      margin: margin,
      elevation: 0,
      clipBehavior: clipBehavior,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: colors.outlineVariant,
          width: SenapathShape.borderWidth,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class SenapathMetric extends StatelessWidget {
  /// Membuat tampilan metrik berisi label, nilai, dan satuan opsional.
  const SenapathMetric({
    required this.label,
    required this.value,
    this.unit,
    this.accent = SenapathColors.ink,
    super.key,
  });

  final String label;
  final String value;
  final String? unit;
  final Color accent;

  /// Membangun kolom label kapital, nilai besar, dan satuan bila tersedia.
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label.toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
      const SizedBox(height: SenapathSpacing.xxs),
      Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: SenapathSpacing.xxs,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: accent,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (unit != null && unit!.isNotEmpty)
            Text(unit!, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    ],
  );
}

class SenapathButton extends StatelessWidget {
  /// Membuat tombol bergaya kartu yang mendukung ikon, status memuat, dan
  /// animasi tekan.
  const SenapathButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.fullWidth = true,
    this.backgroundColor = SenapathColors.blue,
    this.foregroundColor = SenapathColors.white,
    this.animatePress = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;
  final Color backgroundColor;
  final Color foregroundColor;
  final bool animatePress;

  /// Membangun isi tombol, menampilkan indikator saat memuat atau ikon saat
  /// tersedia, lalu membungkusnya sesuai lebar penuh.
  @override
  Widget build(BuildContext context) {
    final button = SenapathCard(
      onTap: animatePress || isLoading ? null : onPressed,
      padding: const EdgeInsets.symmetric(
        horizontal: SenapathSpacing.md,
        vertical: SenapathSpacing.sm,
      ),
      margin: EdgeInsets.zero,
      color: backgroundColor,
      child: Semantics(
        button: true,
        enabled: onPressed != null && !isLoading,
        label: label,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox.square(
                dimension: 19,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foregroundColor,
                ),
              )
            else if (icon != null) ...[
              Icon(icon, color: foregroundColor),
              const SizedBox(width: SenapathSpacing.xs),
            ],
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: foregroundColor, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
    final action = animatePress
        ? PressScale(
            onTap: onPressed,
            enabled: !isLoading && onPressed != null,
            child: button,
          )
        : button;
    return fullWidth ? SizedBox(width: double.infinity, child: action) : action;
  }
}

class SenapathBadge extends StatelessWidget {
  /// Membuat lencana kecil berisi label dan ikon opsional.
  const SenapathBadge({
    required this.label,
    this.color = SenapathColors.accent,
    this.icon,
    super.key,
  });

  final String label;
  final Color color;
  final IconData? icon;

  /// Membangun lencana berlatar warna dengan ikon dan teks yang ditata rapi.
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: SenapathSpacing.sm,
      vertical: SenapathSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: color,
      border: Border.all(
        color: Theme.of(context).colorScheme.outlineVariant,
        width: SenapathShape.borderWidth,
      ),
      borderRadius: BorderRadius.circular(SenapathShape.small),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: SenapathColors.ink),
          const SizedBox(width: SenapathSpacing.xs),
        ],
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: SenapathColors.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}
