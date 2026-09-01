import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/tv_focusable.dart';
import 'home_screen.dart';
import 'section_screen.dart';
import 'settings_screen.dart';

/// Bottom-tab shell with an animated active indicator.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static const _tabs = [
    (icon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.live_tv_rounded, label: 'Live TV'),
    (icon: Icons.movie_rounded, label: 'Movies'),
    (icon: Icons.video_library_rounded, label: 'Series'),
    (icon: Icons.settings_rounded, label: 'Settings'),
  ];

  /// Tabs are built on first visit and kept alive afterwards. The previous
  /// AnimatedSwitcher(KeyedSubtree(ValueKey(_index))) destroyed and rebuilt
  /// the whole screen on every switch — entrance animations replayed, scroll
  /// positions reset, and weak TV boxes visibly stalled on each tab change.
  final List<Widget?> _built = List.filled(5, null);

  Widget _pageFor(int i) => switch (i) {
        0 => const HomeScreen(),
        1 => const SectionScreen(type: ContentType.live),
        2 => const SectionScreen(type: ContentType.movie),
        3 => const SectionScreen(type: ContentType.series),
        _ => const SettingsScreen(),
      };

  @override
  Widget build(BuildContext context) {
    _built[_index] ??= _pageFor(_index);
    return Scaffold(
      body: Stack(
        children: [
          for (var i = 0; i < _built.length; i++)
            if (_built[i] != null)
              Offstage(
                offstage: i != _index,
                // Hidden tabs must not keep animating (shimmers, carousel).
                child: TickerMode(enabled: i == _index, child: _built[i]!),
              ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Ybox.surface,
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.05)),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: TvFocusable(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _index = i);
                      },
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _index = i);
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 4),
                              decoration: BoxDecoration(
                                color: _index == i
                                    ? Ybox.accent.withOpacity(0.14)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Icon(
                                _tabs[i].icon,
                                size: 24,
                                color: _index == i ? Ybox.accent : Ybox.textDim,
                              ),
                            ),
                            const SizedBox(height: 2),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 220),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: _index == i
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: _index == i ? Ybox.accent : Ybox.textDim,
                              ),
                              child: Text(_tabs[i].label),
                            ),
                          ],
                        ),
                      ),
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
