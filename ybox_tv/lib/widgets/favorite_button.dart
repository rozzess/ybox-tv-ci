import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'tv_focusable.dart';

/// Heart toggle with a green pulse + haptic on favorite.
class FavoriteButton extends StatefulWidget {
  final Channel channel;
  final double size;

  const FavoriteButton({super.key, required this.channel, this.size = 22});

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
    lowerBound: 0,
    upperBound: 0.5,
  );

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final state = AppScope.read(context);
    HapticFeedback.mediumImpact();
    final added = await state.toggleFavorite(widget.channel);
    if (added && mounted) {
      _pulse.forward(from: 0).then((_) => _pulse.reverse());
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final fav = state.isFavorite(widget.channel);
    return TvFocusable(
      borderRadius: BorderRadius.circular(999),
      onTap: _toggle,
      child: GestureDetector(
        onTap: _toggle,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(10), // >=44pt tap target
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) => Transform.scale(
              scale: 1 + _pulse.value,
              child: Icon(
                fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                size: widget.size,
                color: fav ? Ybox.accent : Ybox.textDim,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
