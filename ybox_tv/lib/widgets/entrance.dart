import 'package:flutter/material.dart';

import '../services/device_service.dart';

/// Staggered entrance: fades + slides its child in after `index * 40ms`.
///
/// Skipped on TV: every tile scrolling into a grid replays it, keeping the
/// weak GPU of a set-top box compositing fades non-stop while browsing.
class Entrance extends StatefulWidget {
  final int index;
  final Widget child;

  const Entrance({super.key, this.index = 0, required this.child});

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    if (DeviceService.isTv) return;
    Future.delayed(Duration(milliseconds: 40 * widget.index.clamp(0, 14)), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (DeviceService.isTv) return widget.child;
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.08),
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
