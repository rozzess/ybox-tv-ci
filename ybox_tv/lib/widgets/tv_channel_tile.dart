import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';

/// Extra-large, TV-scale poster tile. Designed to be read from across the
/// room on a 10-foot UI: big poster, big title, thick accent focus ring and
/// a strong scale-up so the current D-pad target is unmistakable.
class TvChannelTile extends StatefulWidget {
  final Channel channel;
  final VoidCallback onTap;
  final double width;
  final double height;
  final bool showFavorite;

  const TvChannelTile({
    super.key,
    required this.channel,
    required this.onTap,
    this.width = 210,
    this.height = 300,
    this.showFavorite = false,
  });

  @override
  State<TvChannelTile> createState() => _TvChannelTileState();
}

class _TvChannelTileState extends State<TvChannelTile> {
  bool _focused = false;

  void _activate() {
    HapticFeedback.selectionClick();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      enabled: true,
      onShowFocusHighlight: (v) {
        if (_focused != v && mounted) setState(() => _focused = v);
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _activate();
            return null;
          },
        ),
      },
      child: GestureDetector(
        onTap: _activate,
        child: AnimatedScale(
          scale: _focused ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Ybox.radius),
              border: Border.all(
                color: _focused ? Ybox.accent : Colors.transparent,
                width: 4,
              ),
              boxShadow: _focused ? Ybox.glow(0.45) : null,
            ),
            child: Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                color: Ybox.card,
                borderRadius: BorderRadius.circular(Ybox.radius),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _TvLogo(
                    url: widget.channel.logoUrl,
                    name: widget.channel.name,
                    decodeWidth: widget.width,
                  ),
                  // Bottom scrim so the title stays readable over any image.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xCC0E0E10)],
                        stops: [0.45, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Text(
                      widget.channel.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Ybox.textHigh,
                        height: 1.15,
                      ),
                    ),
                  ),
                  if (widget.channel.type == ContentType.live)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: _LiveBadge(),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Ybox.danger,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          const Text(
            'LIVE',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _TvLogo extends StatelessWidget {
  final String? url;
  final String name;
  final double decodeWidth;

  const _TvLogo({
    required this.url,
    required this.name,
    required this.decodeWidth,
  });

  @override
  Widget build(BuildContext context) {
    if (url == null) return _fallback();
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final dw = (decodeWidth.isFinite ? decodeWidth : 200.0);
    return Image.network(
      url!,
      fit: BoxFit.cover,
      cacheWidth: (dw * dpr).round(),
      errorBuilder: (_, __, ___) => _fallback(),
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : Container(color: Ybox.card),
    );
  }

  Widget _fallback() {
    final letter = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    return Container(
      color: Ybox.groupColor(name).withOpacity(0.18),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.w700,
          color: Ybox.groupColor(name),
        ),
      ),
    );
  }
}
