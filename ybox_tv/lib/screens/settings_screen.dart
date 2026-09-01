import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/admin_sync.dart';
import '../services/subtitle_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/pressable_tile.dart';
import 'playlists_screen.dart';

/// Settings: admin link, device info, account, maintenance.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Future<void> _syncNow() async {
    final ok = await AppScope.read(context).syncNow();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? 'Synced.'
            : 'Offline — will sync automatically when you reconnect.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = AppScope.of(context);
    final sync = state.adminSync;
    final isAdmin = state.isAdmin;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const _SectionLabel('Playlists'),
          if (isAdmin) ...[
            _Tile(
              icon: Icons.playlist_play_rounded,
              title: 'Manage playlists',
              subtitle: 'Active: ${state.active?.name ?? '—'}',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const PlaylistsScreen())),
            ),
            _Tile(
              icon: Icons.restore_rounded,
              title: 'Restore built-in playlist',
              subtitle: 'Reset YBOX TV account to factory settings',
              onTap: () async {
                await AppScope.read(context).restoreBuiltin();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Built-in playlist restored')));
                }
              },
            ),
          ] else ...[
            // Users see playlist names only — no details, no management.
            for (final p in state.usablePlaylists)
              _Tile(
                icon: p.id == state.active?.id
                    ? Icons.play_circle_rounded
                    : Icons.playlist_play_rounded,
                title: p.name,
                subtitle: p.id == state.active?.id ? 'Active' : null,
                onTap: p.id == state.active?.id
                    ? null
                    : () => AppScope.read(context).setActive(p),
              ),
            if (state.usablePlaylists.isEmpty)
              const _Tile(
                icon: Icons.playlist_remove_rounded,
                title: 'No playlists yet',
                subtitle: 'Your admin will push playlists to this device',
                onTap: null,
              ),
          ],
          const SizedBox(height: 24),
          const _SectionLabel('Sync'),
          _Tile(
            icon: Icons.sync_rounded,
            title: 'Sync now',
            subtitle: sync.connected
                ? 'Connected — changes arrive instantly'
                : 'Offline — syncs automatically when reconnected',
            trailing: state.syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Ybox.accent),
                  )
                : _StatusDot(connected: sync.connected),
            onTap: state.syncing ? null : _syncNow,
          ),
          if (isAdmin) ...[
            const SizedBox(height: 24),
            const _SectionLabel('Admin'),
            _Tile(
              icon: Icons.perm_device_information_rounded,
              title: 'Device ID',
              subtitle: sync.deviceId,
              onTap: () {
                Clipboard.setData(ClipboardData(text: sync.deviceId));
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Device ID copied')));
              },
            ),
          ],
          const SizedBox(height: 24),
          const _SectionLabel('Account'),
          _Tile(
            icon: Icons.person_rounded,
            title: state.auth.name?.isNotEmpty == true
                ? state.auth.name!
                : (state.auth.username ?? 'Signed in'),
            subtitle: isAdmin
                ? 'Admin account — tap to sign out'
                : 'Tap to sign out',
            onTap: () => state.signOut(),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('Subtitles'),
          _SubtitleSettingsTile(),
          const SizedBox(height: 24),
          const _SectionLabel('About'),
          const _Tile(
            icon: Icons.info_outline_rounded,
            title: 'YBOX TV',
            subtitle: 'Version ${AdminSync.appVersion}',
            onTap: null,
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: Ybox.textDim,
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _Tile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PressableTile(
        onTap: onTap,
        glowOnPress: onTap != null,
        borderRadius: BorderRadius.circular(Ybox.radiusSm),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Ybox.surface,
            borderRadius: BorderRadius.circular(Ybox.radiusSm),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Ybox.accent.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Ybox.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Ybox.textHigh,
                        )),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: Ybox.textDim),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

class _SubtitleSettingsTile extends StatefulWidget {
  @override
  State<_SubtitleSettingsTile> createState() => _SubtitleSettingsTileState();
}

class _SubtitleSettingsTileState extends State<_SubtitleSettingsTile> {
  SubtitleSettings? _settings;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await SubtitleSettings.load();
    if (mounted) setState(() => _settings = s);
  }

  Future<void> _openEditor() async {
    final current = _settings ?? const SubtitleSettings();
    final result = await showDialog<SubtitleSettings>(
      context: context,
      builder: (_) => _SubtitleSettingsDialog(settings: current),
    );
    if (result != null) {
      await result.save();
      setState(() => _settings = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _settings;
    final configured = s?.hasCredentials == true;
    final lang = s?.language ?? 'en';
    return _Tile(
      icon: Icons.subtitles_rounded,
      title: configured ? 'Subtitles configured' : 'Set up subtitles',
      subtitle: configured
          ? 'Fetch on the $lang track for movies & shows'
          : 'Free SubDL API key — no login needed',
      onTap: _openEditor,
    );
  }
}

class _SubtitleSettingsDialog extends StatefulWidget {
  final SubtitleSettings settings;

  const _SubtitleSettingsDialog({required this.settings});

  @override
  State<_SubtitleSettingsDialog> createState() =>
      _SubtitleSettingsDialogState();
}

class _SubtitleSettingsDialogState extends State<_SubtitleSettingsDialog> {
  late final TextEditingController _key = TextEditingController(
      text: widget.settings.apiKey);
  late String _language = widget.settings.language;

  static const _languages = <String, String>{
    'en': 'English',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'pt': 'Portuguese',
    'it': 'Italian',
    'ru': 'Russian',
    'ar': 'Arabic',
    'tr': 'Turkish',
    'hi': 'Hindi',
    'zh': 'Chinese',
    'ja': 'Japanese',
    'ko': 'Korean',
    'nl': 'Dutch',
    'pl': 'Polish',
    'el': 'Greek',
    'he': 'Hebrew',
    'sv': 'Swedish',
  };

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasKey = _key.text.trim().isNotEmpty;
    return AlertDialog(
      backgroundColor: const Color(0xFF1B1C1F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Subtitle service',
          style: TextStyle(color: Ybox.textHigh)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Subtitles come from SubDL (free tier) — a free API key is '
              'embedded, so movies and shows work out of the box. Replace the '
              'key here if yours has a higher quota, and pick a default '
              'language.',
              style: TextStyle(fontSize: 12.5, color: Ybox.textDim),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _key,
              enabled: true,
              decoration: const InputDecoration(
                labelText: 'SubDL API key',
                hintText: 'subdl_...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 14),
            Text('API keys stay on this device (shared_preferences) — '
                'nothing is sent to YBOX\'s servers.',
                style: TextStyle(fontSize: 11.5, color: Ybox.textDim)),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _language,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Default subtitle language',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                for (final e in _languages.entries)
                  DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value,
                        style: TextStyle(color: Ybox.textHigh)),
                  ),
              ],
              onChanged: (v) => setState(() => _language = v ?? 'en'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: hasKey
              ? () => Navigator.of(context).pop(SubtitleSettings(
                    apiKey: _key.text.trim(),
                    language: _language,
                  ))
              : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _StatusDot extends StatelessWidget {
  final bool connected;

  const _StatusDot({required this.connected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: connected ? Ybox.accent : Ybox.textDim,
        shape: BoxShape.circle,
        boxShadow: connected ? Ybox.glow(0.5) : null,
      ),
    );
  }
}
