import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/content_rail.dart';
import '../widgets/empty_state.dart';
import '../widgets/entrance.dart';
import '../widgets/pressable_tile.dart';
import '../widgets/shimmer.dart';
import 'chat_screen.dart';
import 'group_detail_screen.dart';
import 'player_screen.dart';
import 'search_screen.dart';
import 'series_detail_screen.dart';

/// Reusable section screen: favorites rail on top, then group cards.
class SectionScreen extends StatefulWidget {
  final ContentType type;

  const SectionScreen({super.key, required this.type});

  @override
  State<SectionScreen> createState() => _SectionScreenState();
}

class _SectionScreenState extends State<SectionScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppScope.read(context).ensureLoaded(widget.type);
    });
  }

  void _openItem(Channel c) {
    if (c.type == ContentType.series && !c.isPlayable) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => SeriesDetailScreen(series: c)));
    } else {
      PlayerScreen.open(context, c);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = AppScope.of(context);
    final t = widget.type;
    final loading = state.isLoading(t);
    final error = state.errorOf(t);
    final groups = state.groupsOf(t);
    final favorites = state.favoritesOf(t);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.label),
        actions: [
          IconButton(
            iconSize: 26,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SearchScreen(type: t))),
            icon: const Icon(Icons.search_rounded, color: Ybox.textHigh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: Ybox.accent,
        backgroundColor: Ybox.surface,
        onRefresh: () => AppScope.read(context)
            .ensureLoaded(t, force: true),
        child: Builder(
          builder: (context) {
            if (state.subscriptionExpired) {
              return ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: EmptyState(
                      icon: Icons.lock_clock_rounded,
                      title: 'Subscription expired',
                      message:
                          'Your access has ended. Message your admin to '
                          'renew your subscription.',
                      ctaLabel: 'Contact admin',
                      onCta: () => ChatScreen.open(context),
                    ),
                  ),
                ],
              );
            }
            if (loading && groups.isEmpty) {
              return ListView(
                physics: const NeverScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 8),
                  ShimmerRail(tileHeight: 150, tileWidth: 140),
                  SizedBox(height: 24),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        ShimmerBox(height: 84),
                        SizedBox(height: 12),
                        ShimmerBox(height: 84),
                        SizedBox(height: 12),
                        ShimmerBox(height: 84),
                        SizedBox(height: 12),
                        ShimmerBox(height: 84),
                      ],
                    ),
                  ),
                ],
              );
            }
            if (error != null && groups.isEmpty) {
              return ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: EmptyState(
                      icon: Icons.wifi_off_rounded,
                      title: 'Couldn\'t load ${t.label}',
                      message:
                          'Check your internet connection and playlist, '
                          'then try again.',
                      ctaLabel: 'Retry',
                      onCta: () =>
                          AppScope.read(context).ensureLoaded(t, force: true),
                    ),
                  ),
                ],
              );
            }
            if (groups.isEmpty) {
              return ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: EmptyState(
                      icon: Icons.live_tv_rounded,
                      title: 'Nothing here yet',
                      message:
                          'This playlist has no ${t.label.toLowerCase()} '
                          'content. Try another playlist.',
                    ),
                  ),
                ],
              );
            }
            return ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                const SizedBox(height: 8),
                // Favorites pinned on top of groups
                FavoritesRail(favorites: favorites, onTapItem: _openItem),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                  child: Row(
                    children: [
                      Text('Groups',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(width: 8),
                      Text('${groups.length}',
                          style: TextStyle(
                              fontSize: 14, color: Ybox.textDim)),
                    ],
                  ),
                ),
                for (var i = 0; i < groups.length; i++)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Entrance(
                      index: i,
                      child: _GroupCard(
                        group: groups[i],
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => GroupDetailScreen(
                                type: t, groupName: groups[i].name),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final Group group;
  final VoidCallback onTap;

  const _GroupCard({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Ybox.groupColor(group.name);
    return PressableTile(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Ybox.surface,
          borderRadius: BorderRadius.circular(Ybox.radius),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(
                group.name.characters.first.toUpperCase(),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
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
                    '${group.count} ${group.type.itemLabel.toLowerCase()}',
                    style: TextStyle(fontSize: 13, color: Ybox.textDim),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Ybox.textDim),
          ],
        ),
      ),
    );
  }
}
