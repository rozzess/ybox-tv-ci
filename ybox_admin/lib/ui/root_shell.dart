import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/admin_state.dart';
import '../theme.dart';
import 'screens/chat_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/devices_screen.dart';
import 'screens/playlists_screen.dart';
import 'screens/users_screen.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static const _screens = [
    DashboardScreen(),
    DevicesScreen(),
    PlaylistsScreen(),
    UsersScreen(),
    ChatScreen(),
  ];

  static const _items = [
    (Icons.dashboard_outlined, Icons.dashboard, 'Home'),
    (Icons.devices_other_outlined, Icons.devices_other, 'Devices'),
    (Icons.playlist_play_outlined, Icons.playlist_play, 'Playlists'),
    (Icons.person_outline, Icons.person, 'Users'),
    (Icons.chat_bubble_outline, Icons.chat_bubble, 'Chat'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: KeyedSubtree(
          key: ValueKey(_index),
          child: _screens[_index],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: YColors.surface,
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.06)),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                for (var i = 0; i < _items.length; i++)
                  Expanded(
                    child: _NavItem(
                      icon: _index == i ? _items[i].$2 : _items[i].$1,
                      label: _items[i].$3,
                      selected: _index == i,
                      showBadge: i == 4,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _index = i);
                      },
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

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool showBadge;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? YColors.accent : YColors.text(0.45);
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedScale(
            scale: selected ? 1.15 : 1.0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: showBadge
                ? AnimatedBuilder(
                    animation: AdminState.instance,
                    builder: (context, _) {
                      final unread = AdminState.instance.unreadChats;
                      return Badge(
                        isLabelVisible: unread > 0,
                        label: Text('$unread'),
                        backgroundColor: YColors.danger,
                        child: Icon(icon, color: color, size: 24),
                      );
                    },
                  )
                : Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
