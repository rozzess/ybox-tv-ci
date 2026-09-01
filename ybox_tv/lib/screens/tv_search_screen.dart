import 'dart:async';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/tv_channel_tile.dart';
import '../widgets/tv_item_panel.dart';
import 'player_screen.dart';
import 'series_detail_screen.dart';

/// TV-scale search: type selector + large text field + big poster grid of
/// results. Uses the platform on-screen keyboard when the field is focused.
class TvSearchScreen extends StatefulWidget {
  const TvSearchScreen({super.key});

  @override
  State<TvSearchScreen> createState() => _TvSearchScreenState();
}

class _TvSearchScreenState extends State<TvSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  ContentType? _type; // null = all content types

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = AppScope.read(context);
      for (final t in ContentType.values) {
        s.ensureLoaded(t);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _query = v.trim());
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

  Future<void> _openItem(Channel c) async {
    final play = await TvItemPanel.show(context, c);
    if (play == true && mounted) _enterItem(c);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final q = _query.toLowerCase();
    final types = _type == null ? ContentType.values : [_type!];

    final results = q.isEmpty
        ? <Channel>[]
        : types
            .expand((t) => state.itemsOf(t))
            .where((c) =>
                c.name.toLowerCase().contains(q) ||
                c.group.toLowerCase().contains(q))
            .take(200)
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Text(
            'Search',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: Ybox.textHigh,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 64,
                  child: TextField(
                    controller: _controller,
                    onChanged: _onChanged,
                    style: const TextStyle(fontSize: 24),
                    decoration: InputDecoration(
                      hintText: 'Search movies, shows or channels…',
                      hintStyle: const TextStyle(fontSize: 22),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.search_rounded,
                            color: Ybox.textDim, size: 30),
                      ),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _controller.clear();
                                setState(() => _query = '');
                              },
                              icon: Icon(Icons.close_rounded,
                                  color: Ybox.textDim, size: 28),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              _TypeChip(
                label: 'All',
                selected: _type == null,
                onTap: () => setState(() => _type = null),
              ),
              _TypeChip(
                label: 'Live',
                selected: _type == ContentType.live,
                onTap: () => setState(() => _type = ContentType.live),
              ),
              _TypeChip(
                label: 'Movies',
                selected: _type == ContentType.movie,
                onTap: () => setState(() => _type = ContentType.movie),
              ),
              _TypeChip(
                label: 'Series',
                selected: _type == ContentType.series,
                onTap: () => setState(() => _type = ContentType.series),
              ),
            ],
          ),
        ),
        Expanded(
          child: q.isEmpty
              ? const EmptyState(
                  icon: Icons.search_rounded,
                  title: 'Search everything',
                  message: 'Type above to search across every channel at once.',
                )
              : results.isEmpty
                  ? const EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No results',
                      message: 'Nothing matches your search. Try a shorter '
                          'name.',
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 250,
                        mainAxisSpacing: 20,
                        crossAxisSpacing: 20,
                        childAspectRatio: 210 / 300,
                      ),
                      itemCount: results.length,
                      itemBuilder: (context, i) => TvChannelTile(
                        channel: results[i],
                        onTap: () => _openItem(results[i]),
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
        ),
      ],
    );
  }
}

class _TypeChip extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  State<_TypeChip> createState() => _TypeChipState();
}

class _TypeChipState extends State<_TypeChip> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      onShowFocusHighlight: (v) {
        if (_focused != v && mounted) setState(() => _focused = v);
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap();
            return null;
          },
        ),
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: widget.selected
                ? Ybox.accent
                : (_focused ? Ybox.card : Ybox.surface),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: _focused ? Ybox.accent : Colors.transparent,
              width: 2,
            ),
            boxShadow: _focused && !widget.selected ? Ybox.glow(0.4) : null,
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: widget.selected ? Colors.black : Ybox.textHigh,
            ),
          ),
        ),
      ),
    );
  }
}
