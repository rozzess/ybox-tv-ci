import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// The signature Xbox-style interaction: press → scale up + green glow.
///
/// Also focusable, so TV boxes / D-pad remotes can reach every tile: the
/// focused tile shows the same scale + glow, and select/enter activates it.
class PressableTile extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius? borderRadius;
  final bool glowOnPress;

  const PressableTile({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.glowOnPress = true,
  });

  @override
  State<PressableTile> createState() => _PressableTileState();
}

class _PressableTileState extends State<PressableTile> {
  bool _pressed = false;
  bool _focused = false;

  void _set(bool v) {
    if (_pressed != v && mounted) setState(() => _pressed = v);
  }

  void _activate() {
    HapticFeedback.selectionClick();
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(Ybox.radius);
    final highlighted = _pressed || _focused;
    return FocusableActionDetector(
      enabled: widget.onTap != null,
      // Only fires in traditional highlight mode (D-pad/keyboard) — touch
      // devices never see the focus visual.
      onShowFocusHighlight: (v) {
        if (_focused != v && mounted) setState(() => _focused = v);
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            if (widget.onTap != null) _activate();
            return null;
          },
        ),
      },
      child: GestureDetector(
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap == null ? null : _activate,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: highlighted ? 1.06 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: highlighted && widget.glowOnPress ? Ybox.glow() : null,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
