import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/entrance.dart';
import '../widgets/favorite_button.dart';
import '../widgets/pressable_tile.dart';
import '../widgets/shimmer.dart';
import '../widgets/tv_focusable.dart';
import 'player_screen.dart';

/// Series page: cover, plot, season picker, episode list.
class SeriesDetailScreen extends StatefulWidget {
  final Channel series;

  const SeriesDetailScreen({super.key, required this.series});

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  SeriesInfo? _info;
  String? _error;
  int _seasonIdx = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _info = null;
      _error = null;
    });
    try {
      final api = await AppScope.read(context).xtreamForActive();
      if (api == null) {
        setState(() => _error = 'Series details need an Xtream playlist.');
        return;
      }
      final info = await api.seriesInfo(widget.series.id, widget.series.name);
      if (mounted) setState(() => _info = info);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load series details.');
    }
  }

  void _play(Episode ep) {
    PlayerScreen.open(
      context,
      widget.series,
      url: ep.streamUrl,
      title: '${widget.series.name} · S${ep.season} E${ep.episodeNum}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(color: Ybox.textHigh),
        title: Text(widget.series.name,
            style: const TextStyle(fontSize: 20),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        actions: [
          FavoriteButton(channel: widget.series),
          const SizedBox(width: 8),
        ],
      ),
      body: _error != null
          ? EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Something went wrong',
              message: _error!,
              ctaLabel: 'Retry',
              onCta: _load,
            )
          : info == null
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ShimmerBox(height: 180),
                      SizedBox(height: 16),
                      ShimmerBox(height: 44),
                      SizedBox(height: 16),
                      ShimmerBox(height: 72),
                      SizedBox(height: 12),
                      ShimmerBox(height: 72),
                    ],
                  ),
                )
              : _buildBody(info),
    );
  }

  Widget _buildBody(SeriesInfo info) {
    final seasons = info.seasons;
    final season = seasons.isEmpty
        ? null
        : seasons[_seasonIdx.clamp(0, seasons.length - 1)];

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        // Cover header
        if ((info.cover ?? widget.series.logoUrl) != null)
          Container(
            height: 200,
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Ybox.radius),
              color: Ybox.card,
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.network(
              (info.cover ?? widget.series.logoUrl)!,
              fit: BoxFit.cover,
              // Bound the decode — covers can be multi-megapixel posters.
              cacheWidth: (MediaQuery.sizeOf(context).width *
                      MediaQuery.devicePixelRatioOf(context))
                  .round(),
              errorBuilder: (_, __, ___) => Container(color: Ybox.card),
            ),
          ),
        if (info.plot != null && info.plot!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child:
                Text(info.plot!, style: Theme.of(context).textTheme.bodySmall),
          ),
        if (seasons.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text('No episodes available',
                  style: TextStyle(color: Ybox.textHigh)),
            ),
          )
        else ...[
          // Season chips
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: seasons.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final selected = i == _seasonIdx;
                return TvFocusable(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => setState(() => _seasonIdx = i),
                  child: GestureDetector(
                    onTap: () => setState(() => _seasonIdx = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? Ybox.accent : Ybox.surface,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: selected ? Ybox.glow(0.25) : null,
                      ),
                      child: Text(
                        'Season ${seasons[i].season}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: selected ? Colors.black : Ybox.textDim,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < (season?.episodes.length ?? 0); i++)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Entrance(
                index: i % 10,
                child: _EpisodeRow(
                  episode: season!.episodes[i],
                  onTap: () => _play(season.episodes[i]),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _EpisodeRow extends StatelessWidget {
  final Episode episode;
  final VoidCallback onTap;

  const _EpisodeRow({required this.episode, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressableTile(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Ybox.radiusSm),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Ybox.surface,
          borderRadius: BorderRadius.circular(Ybox.radiusSm),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Ybox.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                '${episode.episodeNum}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Ybox.accent,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                episode.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Ybox.textHigh,
                ),
              ),
            ),
            const Icon(Icons.play_circle_fill_rounded,
                color: Ybox.accent, size: 32),
          ],
        ),
      ),
    );
  }
}
