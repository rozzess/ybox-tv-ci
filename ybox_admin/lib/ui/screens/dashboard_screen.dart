import 'package:flutter/material.dart';

import '../../services/admin_state.dart';
import '../../theme.dart';
import '../widgets/entrance.dart';
import '../widgets/stat_tile.dart';
import '../widgets/status_orb.dart';
import '../widgets/ybox_widgets.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AdminState.instance;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final ok = state.cloudOk;
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(YSpace.l),
            children: [
              Entrance(
                index: 0,
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('YBOX Admin', style: YText.title),
                    ),
                    const LiveIndicator(),
                    const SizedBox(width: YSpace.s),
                    IconButton.filledTonal(
                      style: IconButton.styleFrom(
                        backgroundColor: YColors.accentSoft(0.15),
                      ),
                      tooltip: 'Settings',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.settings_outlined,
                          color: YColors.accent),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: YSpace.xs),
              Entrance(
                index: 1,
                child: Text(
                  ok
                      ? 'Connected to the cloud — every change reaches players instantly, anywhere.'
                      : 'Offline — changes queue locally and sync when you\'re back online.',
                  style: YText.caption,
                ),
              ),
              const SizedBox(height: YSpace.l),
              Entrance(
                index: 2,
                child: Container(
                  padding: const EdgeInsets.all(YSpace.l),
                  decoration: BoxDecoration(
                    color: YColors.surface,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      StatusOrb(active: ok),
                      const SizedBox(height: YSpace.l),
                      Text(
                        ok ? 'CLOUD CONNECTED' : 'OFFLINE',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                          color: ok ? YColors.green : YColors.text(0.5),
                        ),
                      ),
                      const SizedBox(height: YSpace.s),
                      Text(state.projectId, style: YText.mono),
                      const SizedBox(height: YSpace.xs),
                      Text(
                        'Signed in as ${state.admin?.username ?? '—'}',
                        style: YText.caption,
                      ),
                      if (state.backgroundKeepAlive) ...[
                        const SizedBox(height: YSpace.m),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: YSpace.m, vertical: YSpace.xs),
                          decoration: BoxDecoration(
                            color: YColors.green.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 8,
                                height: 8,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: YColors.green,
                                  ),
                                ),
                              ),
                              SizedBox(width: YSpace.s),
                              Text(
                                'Background mode active',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: YColors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: YSpace.l),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: YSpace.m,
                crossAxisSpacing: YSpace.m,
                childAspectRatio: 1.35,
                children: [
                  Entrance(
                    index: 3,
                    child: StatTile(
                      label: 'Devices',
                      value: '${state.devices.length}',
                      icon: Icons.devices,
                    ),
                  ),
                  Entrance(
                    index: 4,
                    child: StatTile(
                      label: 'Online now',
                      value: '${state.onlineDeviceCount}',
                      icon: Icons.podcasts,
                      accent: YColors.green,
                    ),
                  ),
                  Entrance(
                    index: 5,
                    child: StatTile(
                      label: 'User accounts',
                      value: '${state.users.length}',
                      icon: Icons.person,
                    ),
                  ),
                  Entrance(
                    index: 6,
                    child: StatTile(
                      label: 'Active subs',
                      value: '${state.activeSubCount}',
                      icon: Icons.verified,
                      accent: YColors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
