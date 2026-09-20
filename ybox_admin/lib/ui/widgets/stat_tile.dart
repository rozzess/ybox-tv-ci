import 'package:flutter/material.dart';

import '../../theme.dart';
import 'pressable_tile.dart';

class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.accent = YColors.accent,
  });

  @override
  Widget build(BuildContext context) {
    return PressableTile(
      glowColor: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(height: YSpace.m),
          Text(value, style: YText.mono),
          const SizedBox(height: YSpace.xs),
          Text(label, style: YText.caption),
        ],
      ),
    );
  }
}
