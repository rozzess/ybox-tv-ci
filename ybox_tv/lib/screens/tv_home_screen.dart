import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/tv_channel_tile.dart';
import '../widgets/tv_item_panel.dart';
import '../widgets/tv_rail.dart';
import 'chat_screen.dart';
import 'player_screen.dart';
import 'series_detail_screen.dart';

/// TV-scale Home: full-width hero banner + big content rails.
class TvHomeScreen extends StatefulWidget {
  const TvHomeScreen({super.key});

  @override
  State<TvHomeScreen> createState() => _TvHomeScreenState();
}

class _TvHomeScreenState extends State<TvHomeScreen>
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

  void _enterItem(Channel c) {
    if (c.type == ContentType.series && !c.isPlayable) {
      Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => SeriesDetailScreen(series: c)));
    } else {
      PlayerScreen.open(context, c);
    }
  }

  // Every tile on the TV UI asks first (Play / Add to favourites) instead of
  // launching straight into playback; browsing tiles carry no heart.
  Future<void> _openItem(Channel c) async {
    final play = await TvItemPanel.show(context, c);
    if (play == true && mounted) _enterItem(c);
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

    final hero = (liveFavs.isNotEmpty ? liveFavs : live).take(6).toList();
    final continueWatching =
        state.continueWatching.map((e) => e.channel).toList();
    final allFavs = [
      ...state.favoritesOf(ContentType.live),
      ...state.favoritesOf(ContentType.movie),
      ...state.favoritesOf(ContentType.series),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 48),
      children: [
        // Title header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF35E82A), Ybox.accentDark],
                  ),
                  boxShadow: Ybox.glow(0.5),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Y',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greeting(),
                    style: TextStyle(fontSize: 18, color: Ybox.textDim),
                  ),
                  const Text(
                    'YBOX TV',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Ybox.textHigh,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (state.subscriptionExpired)
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: EmptyState(
              icon: Icons.lock_clock_rounded,
              title: 'Subscription expired',
              message:
                  'Your access has ended. Message your admin to renew and get '
                  'right back to watching.',
              ctaLabel: 'Contact admin',
              onCta: () => ChatScreen.open(context),
            ),
          )
        else if (loadingAny)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                TvShimmerBlock(height: 320),
                SizedBox(height: 40),
                TvShimmerRow(),
              ],
            ),
          )
        else ...[
          if (hero.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 0, 0),
              child: _TvHero(items: hero, onTap: _openItem),
            ),
          TvRail(
            title: 'Continue watching',
            items: continueWatching,
            onTapItem: _openItem,
          ),
          TvRail(
            title: 'Favorites',
            items: allFavs,
            onTapItem: _openItem,
          ),
          TvRail(
            title: 'Live TV',
            items: live.take(20).toList(),
            onTapItem: _openItem,
          ),
          TvRail(
            title: 'Movies',
            items: movies.take(20).toList(),
            onTapItem: _openItem,
          ),
          TvRail(
            title: 'Series',
            items: series.take(20).toList(),
            onTapItem: _openItem,
          ),
        ],
      ],
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 6) return 'Good night';
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }
}

/// Big auto-advancing hero banner (TV shows a static, scroll-cued banner
/// instead of a phone carousel to keep focus behavior predictable).
class _TvHero extends StatelessWidget {
  final List<Channel> items;
  final void Function(Channel) onTap;

  const _TvHero({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = items.first;
    // Content area width minus the nav rail + hero side padding.
    final width = (MediaQuery.of(context).size.width - 200 - 48)
        .clamp(320.0, MediaQuery.of(context).size.width);
    return SizedBox(
      height: 320,
      child: TvChannelTile(
        channel: primary,
        onTap: () => onTap(primary),
        width: width,
        height: 320,
      ),
    );
  }
}

class TvShimmerBlock extends StatelessWidget {
  final double height;
  const TvShimmerBlock({super.key, this.height = 320});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Ybox.card,
        borderRadius: BorderRadius.circular(Ybox.radius),
      ),
    );
  }
}

class TvShimmerRow extends StatelessWidget {
  const TvShimmerRow({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: Row(
        children: [
          for (var i = 0; i < 4; i++) ...[
            Container(
              width: 210,
              height: 300,
              decoration: BoxDecoration(
                color: Ybox.card,
                borderRadius: BorderRadius.circular(Ybox.radius),
              ),
            ),
            const SizedBox(width: 20),
          ],
        ],
      ),
    );
  }
}
