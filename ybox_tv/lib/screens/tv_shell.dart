import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import 'settings_screen.dart';
import 'tv_home_screen.dart';
import 'tv_search_screen.dart';
import 'tv_section_screen.dart';

/// The TV (10-foot) shell, styled like the Apple TV app: a slim black top
/// navigation bar with a brand mark on the left and large pill targets for
/// each section, matched against a great, unobstructed content area below.
/// Built for Android TV / set-top boxes where the user only has a D-pad
/// remote — every nav target is room-readable. The selected tab fills white
/// (black glyph, exactly Apple's focus language); hover shows a thin white
/// ring. The same white-on-black accent carries through every TV screen.
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TvTopBar(
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

/// Apple-style top navigation: brand mark on the left, then one big pill
/// target per section. The selected tab is a solid white pill with black
/// text; a hovered-but-not-selected tab gets a thin white outline.
class _TvTopBar extends StatelessWidget {
  final List<({IconData icon, String label})> items;
  final int index;
  final ValueChanged<int> onChanged;

  const _TvTopBar({
    required this.items,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: Ybox.bg,
        border: Border(
          bottom: BorderSide(color: Color(0x14FFFFFF)),
        ),
      ),
      child: Row(
        children: [
          _BrandMark(),
          const SizedBox(width: 44),
          for (var i = 0; i < items.length; i++) ...[
            _TopNavItem(
              icon: items[i].icon,
              label: items[i].label,
              selected: i == index,
              onTap: () => onChanged(i),
            ),
            const SizedBox(width: 14),
          ],
          const Spacer(),
          Text(
            'D-pad to move · OK to select',
            style: TextStyle(fontSize: 13, color: Ybox.textDim),
          ),
        ],
      ),
    );
  }
}

/// Apple TV+ style brand mark: the classic rounded-square app-icon shape
/// (corners that match Apple's icon radii) filled with the system-gray → 
/// white logo gradient, a black play glyph on top, and a bold wordmark.
class _BrandMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Ybox.accent, Ybox.accentDark],
            ),
            boxShadow: Ybox.glow(0.35),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.play_arrow_rounded,
            size: 30,
            color: Colors.black,
          ),
        ),
        const SizedBox(width: 14),
        const Text(
          'YBOX',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Ybox.textHigh,
            letterSpacing: 1.4,
          ),
        ),
      ],
    );
  }
}

class _TopNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TopNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_TopNavItem> createState() => _TopNavItemState();
}

class _TopNavItemState extends State<_TopNavItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected || _focused;
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
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: widget.selected
                ? Ybox.accent
                : (_focused ? Ybox.card : Colors.transparent),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: _focused && !widget.selected
                  ? Ybox.accent
                  : Colors.transparent,
              width: 2,
            ),
            boxShadow: _focused && !widget.selected ? Ybox.glow(0.4) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 22,
                color: active
                    ? (widget.selected ? Colors.black : Ybox.textHigh)
                    : Ybox.textDim,
              ),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight:
                      active ? FontWeight.w700 : FontWeight.w500,
                  color: active
                      ? (widget.selected ? Colors.black : Ybox.textHigh)
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