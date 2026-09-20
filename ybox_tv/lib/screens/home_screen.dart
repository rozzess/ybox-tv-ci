import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/content_rail.dart';
import '../widgets/empty_state.dart';
import '../widgets/entrance.dart';
import '../widgets/hero_carousel.dart';
import '../widgets/playlist_progress_banner.dart';
import '../widgets/shimmer.dart';
import '../widgets/tv_focusable.dart';
import 'chat_screen.dart';
import 'player_screen.dart';
import 'playlists_screen.dart';
import 'series_detail_screen.dart';

/// Home: greeting, hero carousel, rails.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = AppScope.read(context);
      state.ensureLoaded(ContentType.live);
      state.ensureLoaded(ContentType.movie);
      state.ensureLoaded(ContentType.series);
    });
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 6) return 'Good night';
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  void _openItem(Channel c) {
    if (c.type == ContentType.series && !c.isPlayable) {
      Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => SeriesDetailScreen(series: c)));
    } else {
      PlayerScreen.open(context, c);
    }
  }

  Future<void> _syncNow() async {
    HapticFeedback.selectionClick();
    final ok = await AppScope.read(context).syncNow();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Synced with the admin.'
          : 'Admin unreachable — will keep retrying in the background.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = AppScope.of(context);

    final live = state.itemsOf(ContentType.live);
    final movies = state.itemsOf(ContentType.movie);
    final series = state.itemsOf(ContentType.series);
    final liveFavs = state.favoritesOf(ContentType.live);
    final loadingAny = state.isLoading(ContentType.live) && live.isEmpty;

    // Hero: live favorites first, else first channels.
    final hero = (liveFavs.isNotEmpty ? liveFavs : live).take(6).toList();
    final continueWatching =
        state.continueWatching.map((e) => e.channel).toList();
    final allFavs = [
      ...state.favoritesOf(ContentType.live),
      ...state.favoritesOf(ContentType.movie),
      ...state.favoritesOf(ContentType.series),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: Ybox.accent,
          backgroundColor: Ybox.surface,
          onRefresh: () async {
            final s = AppScope.read(context);
            await Future.wait([
              s.ensureLoaded(ContentType.live, force: true),
              s.ensureLoaded(ContentType.movie, force: true),
              s.ensureLoaded(ContentType.series, force: true),
            ]);
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              // Header
              Entrance(
                index: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_greeting,
                                style: TextStyle(
                                    fontSize: 14, color: Ybox.textDim)),
                            const SizedBox(height: 2),
                            Text('YBOX TV',
                                style:
                                    Theme.of(context).textTheme.headlineMedium),
                          ],
                        ),
                      ),
                      // Sync
                      IconButton(
                        onPressed: state.syncing ? null : _syncNow,
                        icon: state.syncing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Ybox.accent),
                              )
                            : const Icon(Icons.sync_rounded,
                                color: Ybox.textHigh),
                      ),
                      // Chat with unread dot
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            onPressed: () => ChatScreen.open(context),
                            icon: const Icon(Icons.chat_bubble_outline_rounded,
                                color: Ybox.textHigh),
                          ),
                          if (state.unreadChat > 0)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: Ybox.accent,
                                  shape: BoxShape.circle,
                                  boxShadow: Ybox.glow(0.5),
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (state.isAdmin)
                        _PlaylistChip(
                          name: state.active?.name ?? '—',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const PlaylistsScreen()),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Subscription countdown pill
              Entrance(
                index: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: _SubscriptionPill(state: state),
                ),
              ),
              // Playlist background-loading progress
              if (state.playlistProgress != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: PlaylistProgressBanner(state: state),
                ),
              if (state.subscriptionExpired)
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.55,
                  child: EmptyState(
                    icon: Icons.lock_clock_rounded,
                    title: 'Subscription expired',
                    message:
                        'Your access has ended. Message your admin to renew '
                        'and get right back to watching.',
                    ctaLabel: 'Contact admin',
                    onCta: () => ChatScreen.open(context),
                  ),
                )
              else if (loadingAny) ...[
                const ShimmerRail(tileHeight: 190, tileWidth: 300, count: 2),
                const SizedBox(height: 24),
                const ShimmerRail(tileHeight: 150, tileWidth: 140),
              ] else ...[
                Entrance(
                    index: 1,
                    child: HeroCarousel(items: hero, onTap: _openItem)),
                ContentRail(
                  title: 'Continue watching',
                  items: continueWatching,
                  onTapItem: _openItem,
                  entranceIndex: 2,
                ),
                ContentRail(
                  title: 'Favorites',
                  items: allFavs,
                  onTapItem: _openItem,
                  entranceIndex: 3,
                ),
                ContentRail(
                  title: 'Popular Live',
                  items: live.take(15).toList(),
                  onTapItem: _openItem,
                  entranceIndex: 4,
                ),
                ContentRail(
                  title: 'Movies',
                  items: movies.take(15).toList(),
                  onTapItem: _openItem,
                  entranceIndex: 5,
                ),
                ContentRail(
                  title: 'Series',
                  items: series.take(15).toList(),
                  onTapItem: _openItem,
                  entranceIndex: 6,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Countdown pill: time left on the user's subscription.
class _SubscriptionPill extends StatelessWidget {
  final AppState state;

  const _SubscriptionPill({required this.state});

  @override
  Widget build(BuildContext context) {
    // Admins have no subscription surface.
    if (state.isAdmin) return const SizedBox.shrink();

    final remaining = state.subscriptionRemaining;
    final expired = remaining <= Duration.zero;

    final Color color;
    final String label;
    final IconData icon;
    if (expired) {
      color = Ybox.danger;
      label = 'Subscription expired';
      icon = Icons.lock_clock_rounded;
    } else {
      final days = remaining.inDays;
      final hours = remaining.inHours % 24;
      final mins = remaining.inMinutes % 60;
      label = days > 0
          ? '${days}d ${hours}h left'
          : hours > 0
              ? '${hours}h ${mins}m left'
              : '${mins}m left';
      color = days < 3
          ? Ybox.danger
          : days < 7
              ? const Color(0xFFF59E0B) // amber
              : Ybox.accent;
      icon = Icons.timer_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaylistChip extends StatelessWidget {
  final String name;
  final VoidCallback onTap;

  const _PlaylistChip({required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Ybox.accent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Ybox.accent.withOpacity(0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.playlist_play_rounded,
                  color: Ybox.accent, size: 18),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Ybox.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
