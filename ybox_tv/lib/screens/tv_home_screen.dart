import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/tv_focusable.dart';
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
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 48),
      children: [
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
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _TvHero(
                items: hero,
                onPlay: _enterItem,
                onInfo: _openItem,
              ),
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
}

/// Netflix TV-style hero banner: full-width backdrop with a bottom + left
/// scrim, oversized title, and the classic action row (white Play pill,
/// My List toggle, Info). Every button is D-pad focusable.
class _TvHero extends StatefulWidget {
  final List<Channel> items;
  final void Function(Channel) onPlay;
  final void Function(Channel) onInfo;

  const _TvHero({
    required this.items,
    required this.onPlay,
    required this.onInfo,
  });

  @override
  State<_TvHero> createState() => _TvHeroState();
}

class _TvHeroState extends State<_TvHero> {
  @override
  Widget build(BuildContext context) {
    final c = widget.items.first;
    final state = AppScope.of(context);
    final fav = state.isFavorite(c);
    return SizedBox(
      height: 520,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _HeroBackdrop(url: c.logoUrl, name: c.name),
          // Bottom fade into the page background so the hero melts into the
          // rails below it instead of ending on a hard edge.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Ybox.bg],
                stops: [0.4, 1.0],
              ),
            ),
          ),
          // Left scrim so the title + buttons stay readable over bright art.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xE60B0B0B), Colors.transparent],
                stops: [0.0, 0.5],
              ),
            ),
          ),
          Positioned(
            left: 48,
            right: 80,
            bottom: 44,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Type · group eyebrow line
                Text(
                  '${c.type.label.toUpperCase()} · ${c.group}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: Color(0xFFB3B3B3),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  c.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                    color: Ybox.textHigh,
                  ),
                ),
                const SizedBox(height: 26),
                Row(
                  children: [
                    _HeroAction(
                      label: 'Play',
                      icon: Icons.play_arrow_rounded,
                      filled: true,
                      onTap: () => widget.onPlay(c),
                    ),
                    const SizedBox(width: 16),
                    _HeroAction(
                      label: fav ? 'In My List' : 'My List',
                      icon: fav ? Icons.check_rounded : Icons.add_rounded,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        unawaited(state.toggleFavorite(c));
                        if (mounted) setState(() {});
                      },
                    ),
                    const SizedBox(width: 16),
                    _HeroAction(
                      label: 'Info',
                      icon: Icons.info_outline_rounded,
                      onTap: () => widget.onInfo(c),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fills the hero feed with the item's artwork (cropped to a wide banner);
/// falls back to a brand-tinted gradient with the initial when there is none.
class _HeroBackdrop extends StatelessWidget {
  final String? url;
  final String name;

  const _HeroBackdrop({required this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    if (url == null) return _fallback();
    return Image.network(
      url!,
      fit: BoxFit.cover,
      cacheWidth: (MediaQuery.sizeOf(context).width *
              MediaQuery.devicePixelRatioOf(context))
          .round(),
      errorBuilder: (_, __, ___) => _fallback(),
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : Container(color: Ybox.card),
    );
  }

  Widget _fallback() {
    final letter = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Ybox.accentDark, Ybox.bg],
        ),
      ),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 48),
      child: Text(
        letter,
        style: TextStyle(
          fontSize: 200,
          fontWeight: FontWeight.w800,
          color: Ybox.textHigh.withValues(alpha: 0.28),
        ),
      ),
    );
  }
}

/// Netflix hero action: white Play pill or a translucent ghost button.
/// D-pad focusable — the ring shows on focus like every other TV target.
class _HeroAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  const _HeroAction({
    required this.label,
    required this.icon,
    this.filled = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          decoration: BoxDecoration(
            color: filled ? Ybox.textHigh : Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
            border: filled
                ? null
                : Border.all(color: Colors.white.withValues(alpha: 0.55), width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 26,
                  color: filled ? Colors.black : Ybox.textHigh),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: filled ? Colors.black : Ybox.textHigh,
                ),
              ),
            ],
          ),
        ),
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
