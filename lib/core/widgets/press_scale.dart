import 'package:flutter/material.dart';

class PressScale extends StatefulWidget {
  /// Membuat pembungkus yang memperkecil child saat ditekan.
  const PressScale({
    required this.child,
    this.onTap,
    this.enabled = true,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  /// Membuat state yang melacak kondisi tekan.
  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _isPressed = false;

  /// Membangun GestureDetector dengan animasi skala saat ditekan dan dilepas.
  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: widget.enabled ? (_) => setState(() => _isPressed = true) : null,
    onTapUp: widget.enabled ? (_) => setState(() => _isPressed = false) : null,
    onTapCancel: widget.enabled
        ? () => setState(() => _isPressed = false)
        : null,
    onTap: widget.enabled ? widget.onTap : null,
    child: AnimatedScale(
      scale: _isPressed ? 0.95 : 1,
      duration: Duration(milliseconds: _isPressed ? 90 : 240),
      curve: _isPressed ? Curves.easeOutCubic : Curves.easeOutBack,
      child: widget.child,
    ),
  );
}
