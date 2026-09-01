import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import 'chat_screen.dart';
import 'group_detail_screen.dart';

/// TV-scale section browser: a big, room-readable grid of content groups.
/// Left nav picks the type (Live / Movies / Series); this shows the groups
/// as large focusable cards in a 10-foot grid.
class TvSectionScreen extends StatefulWidget {
  final ContentType type;

  const TvSectionScreen({super.key, required this.type});

  @override
  State<TvSectionScreen> createState() => _TvSectionScreenState();
}

class _TvSectionScreenState extends State<TvSectionScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppScope.read(context).ensureLoaded(widget.type);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = AppScope.of(context);
    final t = widget.type;
    final loading = state.isLoading(t);
    final error = state.errorOf(t);
    final groups = state.groupsOf(t);

    if (state.subscriptionExpired) {
      return SizedBox(
        height: MediaQuery.of(context).size.height,
        child: EmptyState(
          icon: Icons.lock_clock_rounded,
          title: 'Subscription expired',
          message: 'Your access has ended. Message your admin to renew your '
              'subscription.',
          ctaLabel: 'Contact admin',
          onCta: () => ChatScreen.open(context),
        ),
      );
    }
    if (loading && groups.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Ybox.accent),
      );
    }
    if (error != null && groups.isEmpty) {
      return EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'Couldn\'t load ${t.label}',
        message: 'Check your internet connection and playlist, then try again.',
        ctaLabel: 'Retry',
        onCta: () => AppScope.read(context).ensureLoaded(t, force: true),
      );
    }
    if (groups.isEmpty) {
      return EmptyState(
        icon: Icons.live_tv_rounded,
        title: 'Nothing here yet',
        message: 'This playlist has no ${t.label.toLowerCase()} content. '
            'Try another playlist.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Row(
            children: [
              Text(
                t.label,
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: Ybox.textHigh,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Ybox.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${groups.length} groups',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Ybox.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 340,
              mainAxisSpacing: 16,
              crossAxisSpacing: 20,
              childAspectRatio: 2.6,
            ),
            itemCount: groups.length,
            itemBuilder: (context, i) => _TvGroupCard(
              group: groups[i],
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      GroupDetailScreen(type: t, groupName: groups[i].name),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TvGroupCard extends StatefulWidget {
  final Group group;
  final VoidCallback onTap;

  const _TvGroupCard({required this.group, required this.onTap});

  @override
  State<_TvGroupCard> createState() => _TvGroupCardState();
}

class _TvGroupCardState extends State<_TvGroupCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final color = Ybox.groupColor(widget.group.name);
    return FocusableActionDetector(
      onShowFocusHighlight: (v) {
        if (_focused != v && mounted) setState(() => _focused = v);
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            HapticFeedback.selectionClick();
            widget.onTap();
            return null;
          },
        ),
      },
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _focused ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              color: Ybox.surface,
              borderRadius: BorderRadius.circular(Ybox.radius),
              border: Border.all(
                color: _focused ? Ybox.accent : color.withOpacity(0.25),
                width: _focused ? 4 : 1,
              ),
              boxShadow: _focused ? Ybox.glow(0.4) : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  margin: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    widget.group.name.characters.first.toUpperCase(),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.group.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          color: Ybox.textHigh,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.group.count} '
                        '${widget.group.type.itemLabel.toLowerCase()}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Ybox.textDim,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: _focused ? Ybox.accent : Ybox.textDim,
                    size: 36,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
