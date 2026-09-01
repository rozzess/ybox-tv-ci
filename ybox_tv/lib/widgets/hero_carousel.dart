import 'dart:async';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import 'pressable_tile.dart';

/// Auto-advancing featured carousel with parallax and page dots.
class HeroCarousel extends StatefulWidget {
  final List<Channel> items;
  final void Function(Channel) onTap;

  const HeroCarousel({super.key, required this.items, required this.onTap});

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  late final PageController _controller =
      PageController(viewportFraction: 0.88);
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || widget.items.length < 2) return;
      // Don't animate while hidden (other tab selected, player on top).
      if (!TickerMode.of(context)) return;
      final next = (_page + 1) % widget.items.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        SizedBox(
          height: 190,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.items.length,
            onPageChanged: (p) => setState(() => _page = p),
            itemBuilder: (context, i) {
              final item = widget.items[i];
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  double offset = 0;
                  if (_controller.position.haveDimensions) {
                    offset = (_controller.page ?? 0) - i;
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: PressableTile(
                      onTap: () => widget.onTap(item),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(Ybox.radius),
                          color: Ybox.card,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Parallax layer
                            Transform.translate(
                              offset: Offset(offset * 40, 0),
                              child: item.logoUrl != null
                                  ? Image.network(
                                      item.logoUrl!,
                                      fit: BoxFit.cover,
                                      // Bound the decode — hero art can be a
                                      // multi-megapixel poster.
                                      cacheWidth: (MediaQuery.sizeOf(context)
                                                  .width *
                                              0.88 *
                                              MediaQuery.devicePixelRatioOf(
                                                  context))
                                          .round(),
                                      errorBuilder: (_, __, ___) =>
                                          _gradient(item),
                                    )
                                  : _gradient(item),
                            ),
                            // Scrim
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Color(0xCC0E0E10),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              left: 20,
                              right: 20,
                              bottom: 16,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                            color: Ybox.textHigh,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          item.group,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: Ybox.textDim),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: Ybox.accent,
                                      shape: BoxShape.circle,
                                      boxShadow: Ybox.glow(0.4),
                                    ),
                                    child: const Icon(
                                        Icons.play_arrow_rounded,
                                        color: Colors.black),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.items.length && i < 8; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _page == i ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _page == i ? Ybox.accent : Ybox.card,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _gradient(Channel item) {
    final c = Ybox.groupColor(item.name);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.withOpacity(0.55), Ybox.card],
        ),
      ),
    );
  }
}
