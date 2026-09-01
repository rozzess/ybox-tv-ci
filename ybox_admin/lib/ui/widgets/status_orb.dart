import 'package:flutter/material.dart';

import '../../theme.dart';

/// Pulsing status orb — green pulse while the server runs, static gray
/// when stopped.
class StatusOrb extends StatefulWidget {
  final bool active;
  final double size;

  const StatusOrb({super.key, required this.active, this.size = 96});

  @override
  State<StatusOrb> createState() => _StatusOrbState();
}

class _StatusOrbState extends State<StatusOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.active ? YColors.green : Colors.white24;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = widget.active ? _controller.value : 0.0;
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withOpacity(0.9),
                color.withOpacity(0.25),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.15 + 0.25 * t),
                blurRadius: 32 + 24 * t,
                spreadRadius: 2 + 6 * t,
              ),
            ],
          ),
          child: Icon(
            widget.active ? Icons.wifi_tethering : Icons.wifi_tethering_off,
            color: Colors.white,
            size: widget.size * 0.42,
          ),
        );
      },
    );
  }
}
