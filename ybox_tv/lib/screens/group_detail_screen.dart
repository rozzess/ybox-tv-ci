import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/device_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/channel_tile.dart';
import '../widgets/empty_state.dart';
import '../widgets/entrance.dart';
import '../widgets/tv_channel_tile.dart';
import '../widgets/tv_item_panel.dart';
import 'player_screen.dart';
import 'series_detail_screen.dart';

/// Items inside one group, as a poster grid with quick filter.
class GroupDetailScreen extends StatefulWidget {
  final ContentType type;
  final String groupName;

  const GroupDetailScreen(
      {super.key, required this.type, required this.groupName});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  String _filter = '';

  void _enterItem(BuildContext context, Channel c) {
    if (c.type == ContentType.series && !c.isPlayable) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => SeriesDetailScreen(series: c)));
    } else {
      PlayerScreen.open(context, c);
    }
  }

  /// On TV, selecting a tile asks first (Play / Add to favourites) instead of
  /// launching playback immediately — browsing tiles show no heart.
  void _openItem(BuildContext context, Channel c) async {
    if (!DeviceService.isTv) {
      _enterItem(context, c);
      return;
    }
    final play = await TvItemPanel.show(context, c);
    if (play == true && context.mounted) _enterItem(context, c);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    var items = state.itemsInGroup(widget.type, widget.groupName);
    if (_filter.isNotEmpty) {
      final q = _filter.toLowerCase();
      items = items.where((c) => c.name.toLowerCase().contains(q)).toList();
    }
    final color = Ybox.groupColor(widget.groupName);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(color: Ybox.textHigh),
        title: Text(widget.groupName,
            style: const TextStyle(fontSize: 20),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        backgroundColor: Color.alphaBlend(color.withOpacity(0.06), Ybox.bg),
      ),
      body: Column(
        children: [
          if (!DeviceService.isTv)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                onChanged: (v) => setState(() => _filter = v),
                decoration: InputDecoration(
                  hintText: 'Filter in ${widget.groupName}…',
                  prefixIcon:
                      Icon(Icons.search_rounded, color: Ybox.textDim),
                ),
              ),
            ),
          Expanded(
            child: items.isEmpty
                ? EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No matches',
                    message: _filter.isEmpty
                        ? 'This group is empty.'
                        : 'Nothing in ${widget.groupName} matches '
                            '"$_filter".',
                  )
                : GridView.builder(
                    padding: DeviceService.isTv
                        ? const EdgeInsets.fromLTRB(24, 16, 24, 48)
                        : const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 250,
                      mainAxisSpacing: 20,
                      crossAxisSpacing: 20,
                      childAspectRatio: 4 / 5,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, i) => Entrance(
                      index: i % 12,
                      child: DeviceService.isTv
                          ? TvChannelTile(
                              channel: items[i],
                              width: double.infinity,
                              height: double.infinity,
                              onTap: () =>
                                  _openItem(context, items[i]),
                            )
                          : ChannelTile(
                              channel: items[i],
                              width: double.infinity,
                              height: double.infinity,
                              onTap: () =>
                                  _openItem(context, items[i]),
                            ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
