import 'package:flutter/material.dart';

abstract final class SenapathColors {
  static const coral = Color(0xFFFF6F61);
  static const indigo = Color(0xFF4B0082);
  static const sky = Color(0xFF00BFFF);
  static const gold = Color(0xFFFFD700);
  static const white = Color(0xFFFFFFFF);
  static const ink = Color(0xFF333333);
  static const pink = Color(0xFFFF4081);
  static const spring = Color(0xFF00FF7F);
  static const violet = Color(0xFF8A2BE2);
  static const canvas = Color(0xFFF5F4EF);
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
  const SenapathAlertDialog({
    this.title,
    this.content,
    this.actions,
    this.contentPadding = const EdgeInsets.fromLTRB(24, 16, 24, 8),
    this.titlePadding = const EdgeInsets.fromLTRB(24, 24, 24, 0),
    this.actionsPadding = const EdgeInsets.fromLTRB(16, 8, 16, 16),
    super.key,
  });

  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final EdgeInsetsGeometry contentPadding;
  final EdgeInsetsGeometry titlePadding;
  final EdgeInsetsGeometry actionsPadding;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: title,
    content: content,
    actions: actions,
    titlePadding: titlePadding,
    contentPadding: contentPadding,
    actionsPadding: actionsPadding,
    actionsOverflowButtonSpacing: SenapathSpacing.xs,
  );
}

abstract final class SenapathShape {
  static const small = 8.0;
  static const medium = 12.0;
  static const large = 16.0;
  static const borderWidth = 3.0;
  static const shadowOffset = 5.0;
}

class SenapathCard extends StatefulWidget {
  const SenapathCard({
    required this.child,
    this.onTap,
    this.padding = EdgeInsets.zero,
    this.margin = const EdgeInsets.symmetric(vertical: 6),
    this.color,
    this.clipBehavior = Clip.none,
    this.borderRadius = SenapathShape.medium,
    this.shadowColor,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? color;
  final Clip clipBehavior;
  final double borderRadius;
  final Color? shadowColor;

  @override
  State<SenapathCard> createState() => _SenapathCardState();
}

class _SenapathCardState extends State<SenapathCard> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed != value && mounted) setState(() => _isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final radius = BorderRadius.circular(widget.borderRadius);
    final shadow = SenapathShape.shadowOffset;
    return Padding(
      padding: widget.margin,
      child: Padding(
        padding: const EdgeInsets.only(
          right: SenapathShape.shadowOffset,
          bottom: SenapathShape.shadowOffset,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: shadow,
              top: shadow,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: widget.shadowColor ?? SenapathColors.ink,
                  borderRadius: radius,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 90),
              curve: Curves.easeOut,
              transform: Matrix4.translationValues(
                _isPressed ? shadow : 0,
                _isPressed ? shadow : 0,
                0,
              ),
              decoration: BoxDecoration(
                color: widget.color ?? surface,
                border: Border.all(
                  color: SenapathColors.ink,
                  width: SenapathShape.borderWidth,
                ),
                borderRadius: radius,
              ),
              child: ClipRRect(
                clipBehavior: widget.clipBehavior,
                borderRadius: radius,
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: widget.onTap,
                    onTapDown: widget.onTap == null
                        ? null
                        : (_) => _setPressed(true),
                    onTapUp: widget.onTap == null
                        ? null
                        : (_) => _setPressed(false),
                    onTapCancel: widget.onTap == null
                        ? null
                        : () => _setPressed(false),
                    borderRadius: radius,
                    child: Padding(
                      padding: widget.padding,
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SenapathMetric extends StatelessWidget {
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
  const SenapathButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.fullWidth = true,
    this.backgroundColor = SenapathColors.coral,
    this.foregroundColor = SenapathColors.ink,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final button = SenapathCard(
      onTap: isLoading ? null : onPressed,
      padding: const EdgeInsets.symmetric(
        horizontal: SenapathSpacing.md,
        vertical: SenapathSpacing.sm,
      ),
      margin: const EdgeInsets.only(
        right: SenapathShape.shadowOffset,
        bottom: SenapathShape.shadowOffset,
      ),
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
    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class SenapathBadge extends StatelessWidget {
  const SenapathBadge({
    required this.label,
    this.color = SenapathColors.sky,
    this.icon,
    super.key,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: SenapathSpacing.sm,
      vertical: SenapathSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: color,
      border: Border.all(color: SenapathColors.ink, width: 2),
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
