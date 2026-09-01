import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import 'tv_channel_tile.dart';

/// Large horizontal rail for the TV Home screen — big poster tiles with a
/// room-scale title header.
class TvRail extends StatelessWidget {
  final String title;
  final List<Channel> items;
  final void Function(Channel) onTapItem;

  const TvRail({
    super.key,
    required this.title,
    required this.items,
    required this.onTapItem,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Ybox.textHigh,
              letterSpacing: 0.3,
            ),
          ),
        ),
        SizedBox(
          height: 300,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 20),
            itemBuilder: (context, i) => TvChannelTile(
              channel: items[i],
              onTap: () => onTapItem(items[i]),
            ),
          ),
        ),
      ],
    );
  }
}
