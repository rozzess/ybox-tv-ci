import 'package:flutter/material.dart';

import '../../services/admin_state.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';
import '../widgets/entrance.dart';
import '../widgets/pressable_tile.dart';
import '../widgets/ybox_widgets.dart';

/// Settings page — pushed from the Dashboard gear icon.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _showChangePasswordSheet(BuildContext context) {
    final current = TextEditingController();
    final fresh = TextEditingController();
    String? error;
    bool busy = false;
    showYSheet(
      context,
      StatefulBuilder(
        builder: (context, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Change my password', style: YText.section),
            const SizedBox(height: YSpace.l),
            YTextField(
                controller: current,
                label: 'Current password',
                obscure: true),
            YTextField(
                controller: fresh, label: 'New password', obscure: true),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: YSpace.s),
                child: Text(
                  error!,
                  style: const TextStyle(color: YColors.danger, fontSize: 13),
                ),
              ),
            YPrimaryButton(
              label: busy ? 'Updating…' : 'Update password',
              icon: Icons.key,
              onPressed: busy
                  ? null
                  : () async {
                      setSheetState(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        await AdminAuth.changeOwnPassword(
                            current.text, fresh.text);
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Password updated')),
                          );
                        }
                      } catch (e) {
                        setSheetState(() {
                          busy = false;
                          error = e is String ? e : 'Could not update';
                        });
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(int index, IconData icon, String title, String body,
      {Widget? trailing, VoidCallback? onTap}) {
    return Entrance(
      index: index,
      child: Padding(
        padding: const EdgeInsets.only(bottom: YSpace.m),
        child: PressableTile(
          onTap: onTap,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(YSpace.m),
                decoration: BoxDecoration(
                  color: YColors.accentSoft(),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: YColors.accent, size: 20),
              ),
              const SizedBox(width: YSpace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: YColors.text(0.95),
                      ),
                    ),
                    const SizedBox(height: YSpace.xs),
                    Text(body, style: YText.caption),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: YSpace.s),
                trailing,
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AdminState.instance;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: AnimatedBuilder(
        animation: state,
        builder: (context, _) => SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(YSpace.l),
            children: [
              _infoTile(
                0,
                Icons.account_circle_outlined,
                'Signed in as ${state.admin?.username ?? '—'}',
                'Tap to change your password.',
                onTap: () => _showChangePasswordSheet(context),
                trailing: Icon(Icons.chevron_right, color: YColors.text(0.3)),
              ),
              _infoTile(
                1,
                Icons.battery_charging_full,
                'Background mode',
                'A silent audio session keeps chat and fleet updates live '
                    'while the app is backgrounded or the screen is off. iOS '
                    'may still stop it under memory pressure — keep the '
                    'device plugged in for 24/7 use.',
                trailing: Switch(
                  value: state.backgroundKeepAlive,
                  onChanged: (v) => state.setKeepAlive(v),
                ),
              ),
              _infoTile(
                2,
                Icons.cloud_done_outlined,
                'Cloud project',
                'Firebase project "${state.projectId}". Users, devices, '
                    'playlists and chat all live here — both apps talk to it '
                    'from anywhere with internet.',
              ),
              _infoTile(
                3,
                Icons.sync,
                'How sync works',
                'Everything is realtime: saving a playlist, granting a '
                    'subscription or sending a message reaches every online '
                    'player within seconds — from any network, no LAN or '
                    'port-forwarding needed. Offline players catch up the '
                    'moment they reconnect.',
              ),
              _infoTile(
                4,
                Icons.shield_outlined,
                'Built-in account',
                'The default Xtream account ships inside YBOX TV. Editing it '
                    'under Playlists replaces the credentials on every device '
                    'without reinstalling.',
              ),
              _infoTile(
                5,
                Icons.info_outline,
                'About',
                'YBOX Admin v2.0.0 — cloud fleet control for YBOX TV players '
                    '(iOS & Android).',
              ),
              const SizedBox(height: YSpace.m),
              Entrance(
                index: 6,
                child: YSecondaryButton(
                  label: 'Sign out',
                  icon: Icons.logout,
                  color: YColors.danger,
                  onPressed: () async {
                    final confirmed = await confirmDialog(
                      context,
                      title: 'Sign out?',
                      message:
                          'Fleet updates and chat stop until you sign back in.',
                      confirmLabel: 'Sign out',
                    );
                    if (confirmed) {
                      await state.signOut();
                      if (context.mounted) {
                        Navigator.of(context).popUntil((r) => r.isFirst);
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
