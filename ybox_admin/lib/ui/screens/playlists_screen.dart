import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/admin_state.dart';
import '../../theme.dart';
import '../widgets/entrance.dart';
import '../widgets/pressable_tile.dart';
import '../widgets/ybox_widgets.dart';
import 'playlist_edit_sheet.dart';

class PlaylistsScreen extends StatelessWidget {
  const PlaylistsScreen({super.key});

  void _showAddChooser(BuildContext context) {
    showYSheet(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add playlist', style: YText.section),
          const SizedBox(height: YSpace.xs),
          Text(
            'Saved playlists go live on every targeted device instantly.',
            style: YText.caption,
          ),
          const SizedBox(height: YSpace.l),
          YPrimaryButton(
            label: 'Xtream account',
            icon: Icons.cloud_outlined,
            onPressed: () {
              Navigator.pop(context);
              showPlaylistEditSheet(context, kind: 'xtream');
            },
          ),
          const SizedBox(height: YSpace.m),
          YSecondaryButton(
            label: 'M3U URL',
            icon: Icons.playlist_play,
            onPressed: () {
              Navigator.pop(context);
              showPlaylistEditSheet(context, kind: 'm3u');
            },
          ),
          const SizedBox(height: YSpace.m),
          YSecondaryButton(
            label: 'M3U file',
            icon: Icons.upload_file,
            onPressed: () {
              Navigator.pop(context);
              showPlaylistEditSheet(context, kind: 'm3ufile');
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AdminState.instance;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final playlists = state.playlists;
        return SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    YSpace.l, YSpace.l, YSpace.l, YSpace.m),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Playlists', style: YText.title),
                    ),
                    const LiveIndicator(),
                    const SizedBox(width: YSpace.s),
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: YColors.accent,
                      ),
                      onPressed: () => _showAddChooser(context),
                      icon: const Icon(Icons.add, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: playlists.isEmpty
                    ? const EmptyState(
                        icon: Icons.playlist_add,
                        title: 'No playlists yet',
                        message:
                            'Add an Xtream account or M3U URL — it reaches '
                            'every targeted player the moment you save.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                            YSpace.l, 0, YSpace.l, YSpace.xl),
                        itemCount: playlists.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: YSpace.m),
                        itemBuilder: (context, index) => Entrance(
                          index: index,
                          child: _PlaylistTile(entry: playlists[index]),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  final PlaylistEntry entry;

  const _PlaylistTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isXtream = entry.kind == 'xtream';
    final isFile = entry.kind == 'm3ufile';
    final subtitle = isXtream
        ? '${entry.server} · ${entry.username}'
        : isFile
            ? 'M3U file · ${(entry.content.length / 1024).round()} KB'
            : entry.url;

    return PressableTile(
      onTap: () => showPlaylistEditSheet(context, existing: entry),
      onLongPress: entry.isBuiltin
          ? null
          : () async {
              final confirmed = await confirmDialog(
                context,
                title: 'Delete playlist?',
                message: '"${entry.name}" disappears from all targeted '
                    'devices immediately.',
              );
              if (confirmed) {
                await AdminState.instance.deletePlaylist(entry.id);
              }
            },
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(YSpace.m),
            decoration: BoxDecoration(
              color: entry.isBuiltin
                  ? YColors.green.withOpacity(0.12)
                  : YColors.accentSoft(),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isXtream
                  ? Icons.cloud_outlined
                  : isFile
                      ? Icons.upload_file
                      : Icons.playlist_play,
              color: entry.isBuiltin ? YColors.green : YColors.accent,
            ),
          ),
          const SizedBox(width: YSpace.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: YColors.text(0.95),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (entry.isBuiltin) ...[
                      const SizedBox(width: YSpace.s),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: YColors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'BUILT-IN',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: YColors.green,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: YSpace.xs),
                Text(
                  subtitle,
                  style: YText.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: YSpace.xs),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.targetsLabel,
                        style:
                            TextStyle(fontSize: 11, color: YColors.text(0.4)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (entry.expiresAt > 0) ...[
                      const SizedBox(width: YSpace.s),
                      Text(
                        entry.expiryLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: entry.expired
                              ? YColors.danger
                              : const Color(0xFFF2A93B),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: YColors.text(0.3)),
        ],
      ),
    );
  }
}
