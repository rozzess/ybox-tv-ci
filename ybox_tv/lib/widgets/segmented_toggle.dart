import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'tv_focusable.dart';

/// iOS-style segmented control with an animated sliding pill.
class SegmentedToggle extends StatelessWidget {
  final List<String> segments;
  final int selected;
  final ValueChanged<int> onChanged;

  const SegmentedToggle({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Ybox.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segWidth = constraints.maxWidth / segments.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: segWidth * selected,
                top: 0,
                bottom: 0,
                width: segWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: Ybox.accent,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: Ybox.glow(0.25),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < segments.length; i++)
                    Expanded(
                      child: TvFocusable(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => onChanged(i),
                        child: GestureDetector(
                          onTap: () => onChanged(i),
                          behavior: HitTestBehavior.opaque,
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 220),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color:
                                    selected == i ? Colors.black : Ybox.textDim,
                              ),
                              child: Text(segments[i]),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
