import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import 'settings_screen.dart';
import 'tv_home_screen.dart';
import 'tv_search_screen.dart';
import 'tv_section_screen.dart';

/// The TV (10-foot) shell: a persistent left navigation rail + a large
/// content area. Built for Android TV / set-top boxes where the user only
/// has a D-pad remote — every nav item is a big, clearly-highlighted focus
/// target. The selected item glows green, exactly like the rest of YBOX.
class TvShell extends StatefulWidget {
  const TvShell({super.key});

  @override
  State<TvShell> createState() => _TvShellState();
}

class _TvShellState extends State<TvShell> {
  int _index = 0;

  static const _navItems = [
    (icon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.live_tv_rounded, label: 'Live TV'),
    (icon: Icons.movie_rounded, label: 'Movies'),
    (icon: Icons.video_library_rounded, label: 'Series'),
    (icon: Icons.search_rounded, label: 'Search'),
    (icon: Icons.settings_rounded, label: 'Settings'),
  ];

  final List<Widget?> _built = List.filled(6, null);

  Widget _pageFor(int i) => switch (i) {
        0 => const TvHomeScreen(),
        1 => const TvSectionScreen(type: ContentType.live),
        2 => const TvSectionScreen(type: ContentType.movie),
        3 => const TvSectionScreen(type: ContentType.series),
        4 => const TvSearchScreen(),
        _ => const SettingsScreen(),
      };

  @override
  Widget build(BuildContext context) {
    _built[_index] ??= _pageFor(_index);
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TvNavRail(
            items: _navItems,
            index: _index,
            onChanged: (i) {
              HapticFeedback.selectionClick();
              setState(() => _index = i);
            },
          ),
          Expanded(
            child: Stack(
              children: [
                for (var i = 0; i < _built.length; i++)
                  if (_built[i] != null)
                    Offstage(
                      offstage: i != _index,
                      child: TickerMode(
                        enabled: i == _index,
                        child: _built[i]!,
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TvNavRail extends StatelessWidget {
  final List<({IconData icon, String label})> items;
  final int index;
  final ValueChanged<int> onChanged;

  const _TvNavRail({
    required this.items,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      decoration: const BoxDecoration(
        color: Ybox.surface,
        border: Border(
          right: BorderSide(color: Color(0x1FFFFFFF)),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Brand header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF35E82A), Ybox.accentDark],
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Y',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'YBOX',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Ybox.textHigh,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            for (var i = 0; i < items.length; i++)
              _NavItem(
                icon: items[i].icon,
                label: items[i].label,
                selected: i == index,
                onTap: () => onChanged(i),
              ),
            const Spacer(),
            // Hint
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Text(
                'Use the D-pad to move · OK to select',
                style: TextStyle(fontSize: 13, color: Ybox.textDim),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
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
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: widget.selected
                ? Ybox.accent.withOpacity(0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.selected || _focused
                  ? (widget.selected ? Ybox.accent : Ybox.accent)
                  : Colors.transparent,
              width: 2,
            ),
            boxShadow: (widget.selected || _focused) ? Ybox.glow(0.35) : null,
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 28,
                color: widget.selected || _focused ? Ybox.accent : Ybox.textDim,
              ),
              const SizedBox(width: 16),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: widget.selected || _focused
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: widget.selected || _focused
                      ? Ybox.textHigh
                      : Ybox.textDim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
