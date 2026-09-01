import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import 'favorite_button.dart';
import 'pressable_tile.dart';

/// Poster-ish tile for rails and grids.
class ChannelTile extends StatelessWidget {
  final Channel channel;
  final VoidCallback onTap;
  final double width;
  final double height;
  final bool showFavorite;

  const ChannelTile({
    super.key,
    required this.channel,
    required this.onTap,
    this.width = 140,
    this.height = 150,
    this.showFavorite = true,
  });

  @override
  Widget build(BuildContext context) {
    return PressableTile(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Ybox.card,
          borderRadius: BorderRadius.circular(Ybox.radiusSm),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _Logo(
                    url: channel.logoUrl,
                    name: channel.name,
                    decodeWidth: width.isFinite ? width : 160,
                  ),
                  if (showFavorite)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: FavoriteButton(channel: channel, size: 18),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
              child: Text(
                channel.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Ybox.textHigh,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Row-style tile for lists (search results, group contents).
class ChannelRow extends StatelessWidget {
  final Channel channel;
  final VoidCallback onTap;

  const ChannelRow({super.key, required this.channel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressableTile(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Ybox.radiusSm),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Ybox.surface,
          borderRadius: BorderRadius.circular(Ybox.radiusSm),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 52,
                height: 52,
                child: _Logo(
                    url: channel.logoUrl,
                    name: channel.name,
                    decodeWidth: 52),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Ybox.textHigh,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    channel.group,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: Ybox.textDim),
                  ),
                ],
              ),
            ),
            FavoriteButton(channel: channel),
          ],
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  final String? url;
  final String name;
  final double decodeWidth; // logical px the logo actually renders at

  const _Logo({
    required this.url,
    required this.name,
    required this.decodeWidth,
  });

  @override
  Widget build(BuildContext context) {
    if (url == null) return _fallback();
    return Image.network(
      url!,
      fit: BoxFit.cover,
      // Decode at display size: panels serve logos at arbitrary (often
      // multi-megapixel) resolutions; hundreds of full-res decodes OOM-kill
      // low-RAM TV boxes and stall scrolling on texture uploads.
      cacheWidth:
          (decodeWidth * MediaQuery.devicePixelRatioOf(context)).round(),
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
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Ybox.groupColor(name),
        ),
      ),
    );
  }
}
