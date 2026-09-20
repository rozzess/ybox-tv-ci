import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Lightweight shimmer skeleton box (no external packages).
class ShimmerBox extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const ShimmerBox({super.key, this.width, this.height, this.borderRadius});

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius:
                widget.borderRadius ?? BorderRadius.circular(Ybox.radiusSm),
            gradient: LinearGradient(
              begin: Alignment(-1.5 + 3 * t, 0),
              end: Alignment(-0.5 + 3 * t, 0),
              colors: const [
                Ybox.surface,
                Ybox.card,
                Ybox.surface,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A rail of shimmer tiles used while a section loads.
class ShimmerRail extends StatelessWidget {
  final double tileWidth;
  final double tileHeight;
  final int count;

  const ShimmerRail({
    super.key,
    this.tileWidth = 140,
    this.tileHeight = 100,
    this.count = 4,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: tileHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) =>
            ShimmerBox(width: tileWidth, height: tileHeight),
      ),
    );
  }
}

/// A vertical list of shimmer rows.
class ShimmerList extends StatelessWidget {
  final int count;
  final double rowHeight;

  const ShimmerList({super.key, this.count = 8, this.rowHeight = 72});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => ShimmerBox(height: rowHeight),
    );
  }
}
