import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import 'channel_tile.dart';
import 'entrance.dart';

/// Horizontal rail with a section header — the Home screen building block.
class ContentRail extends StatelessWidget {
  final String title;
  final List<Channel> items;
  final void Function(Channel) onTapItem;
  final int entranceIndex;

  const ContentRail({
    super.key,
    required this.title,
    required this.items,
    required this.onTapItem,
    this.entranceIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Entrance(
      index: entranceIndex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) => ChannelTile(
                channel: items[i],
                onTap: () => onTapItem(items[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact favorites rail pinned above the group list in each section.
class FavoritesRail extends StatelessWidget {
  final List<Channel> favorites;
  final void Function(Channel) onTapItem;

  const FavoritesRail({
    super.key,
    required this.favorites,
    required this.onTapItem,
  });

  @override
  Widget build(BuildContext context) {
    if (favorites.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              const Icon(Icons.favorite_rounded, color: Ybox.accent, size: 18),
              const SizedBox(width: 8),
              Text('Favorites',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Ybox.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${favorites.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Ybox.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: favorites.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => ChannelTile(
              channel: favorites[i],
              onTap: () => onTapItem(favorites[i]),
            ),
          ),
        ),
      ],
    );
  }
}
