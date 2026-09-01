import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Makes a bare [GestureDetector]-style control reachable from a TV remote:
/// D-pad traversal focuses it (accent ring), select/enter fires [onTap].
///
/// Touch devices are unaffected — the ring only shows in traditional focus
/// highlight mode (no touchscreen, or keyboard in use).
class TvFocusable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  const TvFocusable({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius,
  });

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(Ybox.radius);
    return FocusableActionDetector(
      enabled: widget.onTap != null,
      onShowFocusHighlight: (v) {
        if (_focused != v && mounted) setState(() => _focused = v);
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap?.call();
            return null;
          },
        ),
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: _focused ? Ybox.accent : Colors.transparent,
            width: 2,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}
