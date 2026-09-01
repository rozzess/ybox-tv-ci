import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme.dart';

/// Xbox-dashboard-style pressable card: scales down slightly on press and
/// lights up with a tinted glow.
class PressableTile extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color color;
  final Color glowColor;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  const PressableTile({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.color = YColors.card,
    this.glowColor = YColors.accent,
    this.borderRadius = 16,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  State<PressableTile> createState() => _PressableTileState();
}

class _PressableTileState extends State<PressableTile> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _pressed ? 0.965 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: _pressed
                  ? widget.glowColor.withOpacity(0.6)
                  : Colors.white.withOpacity(0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withOpacity(_pressed ? 0.25 : 0.0),
                blurRadius: 24,
                spreadRadius: 1,
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
