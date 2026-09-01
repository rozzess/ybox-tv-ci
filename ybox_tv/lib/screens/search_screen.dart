import 'dart:async';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/channel_tile.dart';
import '../widgets/empty_state.dart';
import '../widgets/entrance.dart';
import '../widgets/pressable_tile.dart';
import '../widgets/segmented_toggle.dart';
import '../widgets/shimmer.dart';
import 'group_detail_screen.dart';
import 'player_screen.dart';
import 'series_detail_screen.dart';

/// Per-section search with TWO modes: all items, or group names.
class SearchScreen extends StatefulWidget {
  final ContentType type;

  const SearchScreen({super.key, required this.type});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  int _mode = 0; // 0 = all items, 1 = groups

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppScope.read(context).ensureLoaded(widget.type);
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
    final state = AppScope.of(context);
    final t = widget.type;
    final loading = state.isLoading(t);
    final q = _query.toLowerCase();

    final items = q.isEmpty
        ? <Channel>[]
        : state
            .itemsOf(t)
            .where((c) => c.name.toLowerCase().contains(q))
            .take(200)
            .toList();
    final groups = q.isEmpty
        ? state.groupsOf(t)
        : state
            .groupsOf(t)
            .where((g) => g.name.toLowerCase().contains(q))
            .toList();

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(color: Ybox.textHigh),
        title: Text('Search ${t.label}', style: const TextStyle(fontSize: 20)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: _mode == 0
                    ? 'Search all ${t.itemLabel.toLowerCase()}…'
                    : 'Search groups…',
                prefixIcon:
                    Icon(Icons.search_rounded, color: Ybox.textDim),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                        icon: Icon(Icons.close_rounded,
                            color: Ybox.textDim),
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedToggle(
              segments: ['All ${t.itemLabel}', 'Groups'],
              selected: _mode,
              onChanged: (i) => setState(() => _mode = i),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: loading
                ? const ShimmerList(count: 6)
                : _mode == 0
                    ? _buildItems(items)
                    : _buildGroups(groups),
          ),
        ],
      ),
    );
  }

  Widget _buildItems(List<Channel> items) {
    if (_query.isEmpty) {
      return EmptyState(
        icon: Icons.search_rounded,
        title: 'Search everything',
        message: 'Type to search across every group in '
            '${widget.type.label} at once.',
      );
    }
    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No results',
        message: 'Nothing matches "$_query". Try a shorter name.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => Entrance(
        index: i % 10,
        child: ChannelRow(
          channel: items[i],
          onTap: () => _openItem(items[i]),
        ),
      ),
    );
  }

  Widget _buildGroups(List<Group> groups) {
    if (groups.isEmpty) {
      return EmptyState(
        icon: Icons.folder_off_rounded,
        title: 'No groups found',
        message: 'No group name matches "$_query".',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final g = groups[i];
        final color = Ybox.groupColor(g.name);
        return Entrance(
          index: i % 10,
          child: PressableTile(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    GroupDetailScreen(type: widget.type, groupName: g.name))),
            borderRadius: BorderRadius.circular(Ybox.radiusSm),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Ybox.surface,
                borderRadius: BorderRadius.circular(Ybox.radiusSm),
                border: Border.all(color: color.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.folder_rounded, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      g.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Ybox.textHigh,
                      ),
                    ),
                  ),
                  Text('${g.count}',
                      style:
                          TextStyle(fontSize: 13, color: Ybox.textDim)),
                  Icon(Icons.chevron_right_rounded, color: Ybox.textDim),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
