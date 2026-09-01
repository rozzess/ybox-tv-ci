import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// Progress banner shown while the selected playlist loads in the
/// background: stage label, live percentage, and a "ready" state when done.
class PlaylistProgressBanner extends StatelessWidget {
  final AppState state;

  const PlaylistProgressBanner({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final progress = state.playlistProgress;
    if (progress == null) return const SizedBox.shrink();
    final done = progress >= 1.0;
    final percent = (progress.clamp(0.0, 1.0) * 100).round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Ybox.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Ybox.accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: done
                ? const Icon(Icons.check_circle_rounded,
                    color: Ybox.accent, size: 22)
                : CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 2.5,
                    color: Ybox.accent,
                    backgroundColor: Colors.white12,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  done
                      ? 'Playlist ready'
                      : (state.playlistStage.isEmpty
                          ? 'Loading playlist…'
                          : state.playlistStage),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Ybox.textHigh,
                  ),
                ),
                if (!done) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      color: Ybox.accent,
                      backgroundColor: Colors.white12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$percent%',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Ybox.accent,
            ),
          ),
        ],
      ),
    );
  }
}
