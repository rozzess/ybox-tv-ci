import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'tv_focusable.dart';

/// 10-foot "what do you want to do with this?" popup shown when a movie,
/// show or channel tile is selected on the TV UI. Remote-friendly: two big
/// D-pad buttons — Play and Add to Favourites (no busy little heart trapped
/// inside a browsing tile).
class TvItemPanel extends StatefulWidget {
  final Channel channel;

  const TvItemPanel({super.key, required this.channel});

  /// Shows the panel and resolves with true when Play was chosen.
  static Future<bool?> show(BuildContext context, Channel channel) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => TvItemPanel(channel: channel),
    );
  }

  @override
  State<TvItemPanel> createState() => _TvItemPanelState();
}

class _TvItemPanelState extends State<TvItemPanel> {
  bool _fav = false;

  @override
  void initState() {
    super.initState();
    _fav = AppScope.read(context).isFavorite(widget.channel);
  }

  Future<void> _toggleFavorite() async {
    final added = await AppScope.read(context).toggleFavorite(widget.channel);
    if (mounted) {
      HapticFeedback.selectionClick();
      setState(() => _fav = added);
    }
  }

  void _play() => Navigator.of(context).pop(true);

  @override
  Widget build(BuildContext context) {
    final c = widget.channel;
    return Center(
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Ybox.surface,
          borderRadius: BorderRadius.circular(Ybox.radius),
          border: Border.all(color: Colors.white24, width: 1),
          boxShadow: Ybox.glow(0.35),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _Poster(channel: c),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Ybox.textHigh,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        c.group.isEmpty
                            ? c.type.itemLabel
                            : '${c.type.itemLabel} · ${c.group}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          color: Ybox.textDim,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: _PanelButton(
                    icon: Icons.play_arrow_rounded,
                    label: 'Play',
                    primary: true,
                    onTap: _play,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _PanelButton(
                    icon: _fav
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    label: _fav ? 'In favourites' : 'Add to favourites',
                    primary: false,
                    onTap: _toggleFavorite,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool primary;
  final VoidCallback onTap;

  const _PanelButton({
    required this.icon,
    required this.label,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      borderRadius: BorderRadius.circular(Ybox.radius),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
        decoration: BoxDecoration(
          color: primary ? Ybox.accent : Ybox.card,
          borderRadius: BorderRadius.circular(Ybox.radius),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 30,
                color: primary ? Colors.black : Ybox.textHigh),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: primary ? Colors.black : Ybox.textHigh,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Poster extends StatelessWidget {
  final Channel channel;

  const _Poster({required this.channel});

  @override
  Widget build(BuildContext context) {
    final url = channel.logoUrl;
    final fallback = Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        color: Ybox.groupColor(channel.name).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Text(
        channel.name.isEmpty
            ? '?'
            : channel.name.characters.first.toUpperCase(),
        style: TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.w800,
          color: Ybox.groupColor(channel.name),
        ),
      ),
    );
    if (url == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        url,
        width: 92,
        height: 92,
        fit: BoxFit.cover,
        cacheWidth:
            (92 * MediaQuery.devicePixelRatioOf(context)).round(),
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}
