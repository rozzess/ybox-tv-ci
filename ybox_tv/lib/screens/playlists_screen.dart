import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../services/m3u_parser.dart';
import '../services/xtream_api.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/entrance.dart';
import '../widgets/playlist_progress_banner.dart';
import '../widgets/pressable_tile.dart';
import '../widgets/segmented_toggle.dart';

/// Manage playlists: select / add (Xtream, M3U URL, M3U file) / delete.
class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  String? _justActivated;

  Future<void> _activate(Playlist p) async {
    HapticFeedback.mediumImpact();
    await AppScope.read(context).setActive(p);
    setState(() => _justActivated = p.id);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _justActivated = null);
    });
  }

  Future<void> _confirmDelete(Playlist p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Ybox.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Ybox.radius)),
        title: const Text('Delete playlist?',
            style: TextStyle(color: Ybox.textHigh)),
        content: Text(
          '"${p.name}" will be removed. This can\'t be undone.',
          style: TextStyle(color: Ybox.textDim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                Text('Cancel', style: TextStyle(color: Ybox.textDim)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: Ybox.danger)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await AppScope.read(context).deletePlaylist(p.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final playlists = state.playlists;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(color: Ybox.textHigh),
        title: const Text('Playlists', style: TextStyle(fontSize: 22)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _AddPlaylistSheet.show(context),
        backgroundColor: Ybox.accent,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add playlist',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          if (state.playlistProgress != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: PlaylistProgressBanner(state: state),
            ),
          Expanded(child: _buildList(state, playlists)),
        ],
      ),
    );
  }

  Widget _buildList(AppState state, List<Playlist> playlists) {
    return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        itemCount: playlists.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final p = playlists[i];
          final isActive = state.active?.id == p.id;
          final pulsing = _justActivated == p.id;

          Widget card = PressableTile(
            onTap: () => _activate(p),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Ybox.surface,
                borderRadius: BorderRadius.circular(Ybox.radius),
                border: Border.all(
                  color: isActive
                      ? Ybox.accent
                      : Colors.white.withOpacity(0.06),
                  width: isActive ? 1.5 : 1,
                ),
                boxShadow: pulsing ? Ybox.glow(0.45) : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Ybox.accent.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      p.kind == PlaylistKind.xtream
                          ? Icons.dns_rounded
                          : Icons.playlist_play_rounded,
                      color: Ybox.accent,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                p.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Ybox.textHigh,
                                ),
                              ),
                            ),
                            if (p.isBuiltin) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Ybox.accent.withOpacity(0.12),
                                  borderRadius:
                                      BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'BUILT-IN',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Ybox.accent,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          p.kind.label,
                          style: TextStyle(
                              fontSize: 13, color: Ybox.textDim),
                        ),
                      ],
                    ),
                  ),
                  if (isActive)
                    const Icon(Icons.check_circle_rounded,
                        color: Ybox.accent)
                  else
                    Icon(Icons.radio_button_unchecked_rounded,
                        color: Ybox.textDim),
                ],
              ),
            ),
          );

          if (!p.isBuiltin) {
            card = Dismissible(
              key: ValueKey(p.id),
              direction: DismissDirection.endToStart,
              confirmDismiss: (_) async {
                await _confirmDelete(p);
                return false; // deletion handled by state
              },
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                decoration: BoxDecoration(
                  color: Ybox.danger.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(Ybox.radius),
                ),
                child:
                    const Icon(Icons.delete_rounded, color: Ybox.danger),
              ),
              child: card,
            );
          }

          return Entrance(index: i, child: card);
        });
  }
}

/// Bottom sheet to add a playlist (Xtream / M3U URL / M3U file).
class _AddPlaylistSheet extends StatefulWidget {
  const _AddPlaylistSheet();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Ybox.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _AddPlaylistSheet(),
    );
  }

  @override
  State<_AddPlaylistSheet> createState() => _AddPlaylistSheetState();
}

class _AddPlaylistSheetState extends State<_AddPlaylistSheet> {
  int _kind = 0; // 0 xtream, 1 m3u url, 2 m3u file
  final _name = TextEditingController();
  final _server = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _url = TextEditingController();
  String? _filePath;
  String? _fileName;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _server.dispose();
    _user.dispose();
    _pass.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      setState(() {
        _filePath = result.files.single.path;
        _fileName = result.files.single.name;
      });
    }
  }

  Future<void> _save() async {
    final state = AppScope.read(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      Playlist p;
      final id = AppState.newPlaylistId();
      final name = _name.text.trim();
      switch (_kind) {
        case 0:
          if (_server.text.trim().isEmpty ||
              _user.text.trim().isEmpty ||
              _pass.text.trim().isEmpty) {
            throw 'Fill in server, username and password.';
          }
          p = Playlist(
            id: id,
            name: name.isEmpty ? _user.text.trim() : name,
            kind: PlaylistKind.xtream,
            server: XtreamApi.normalizeServer(_server.text),
            username: _user.text.trim(),
            password: _pass.text.trim(),
          );
          final ok = await XtreamApi.fromPlaylist(p).validate();
          if (!ok) throw 'Xtream login failed — check the credentials.';
          break;
        case 1:
          if (_url.text.trim().isEmpty) throw 'Enter the M3U URL.';
          // Xtream get.php links are stored as Xtream accounts — the full
          // M3U body of a big panel is too large for a device to parse.
          final xt = XtreamApi.parseGetPhp(_url.text);
          if (xt != null) {
            p = Playlist(
              id: id,
              name: name.isEmpty ? xt.username : name,
              kind: PlaylistKind.xtream,
              server: xt.server,
              username: xt.username,
              password: xt.password,
            );
            final ok = await XtreamApi.fromPlaylist(p).validate();
            if (!ok) throw 'Xtream login failed — check the credentials.';
            break;
          }
          final channels = await M3uParser.fromUrl(_url.text.trim());
          if (channels.isEmpty) throw 'That URL has no playable entries.';
          p = Playlist(
            id: id,
            name: name.isEmpty ? 'M3U Playlist' : name,
            kind: PlaylistKind.m3uUrl,
            url: _url.text.trim(),
          );
          break;
        default:
          if (_filePath == null) throw 'Pick an M3U file first.';
          final channels = await M3uParser.fromFile(_filePath!);
          if (channels.isEmpty) throw 'That file has no playable entries.';
          p = Playlist(
            id: id,
            name: name.isEmpty ? (_fileName ?? 'M3U File') : name,
            kind: PlaylistKind.m3uFile,
            url: _filePath,
          );
      }
      await state.addPlaylist(p);
      if (mounted) {
        HapticFeedback.mediumImpact();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added "${p.name}"')),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Ybox.textDim,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('Add playlist',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            SegmentedToggle(
              segments: const ['Xtream', 'M3U URL', 'M3U File'],
              selected: _kind,
              onChanged: (i) => setState(() {
                _kind = i;
                _error = null;
              }),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              decoration:
                  const InputDecoration(hintText: 'Name (optional)'),
            ),
            const SizedBox(height: 12),
            if (_kind == 0) ...[
              TextField(
                controller: _server,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                    hintText: 'Server (http://host:port)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _user,
                decoration: const InputDecoration(hintText: 'Username'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pass,
                obscureText: true,
                decoration: const InputDecoration(hintText: 'Password'),
              ),
            ] else if (_kind == 1)
              TextField(
                controller: _url,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                    hintText: 'https://example.com/playlist.m3u'),
              )
            else
              PressableTile(
                onTap: _pickFile,
                borderRadius: BorderRadius.circular(Ybox.radiusSm),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Ybox.card,
                    borderRadius: BorderRadius.circular(Ybox.radiusSm),
                    border: Border.all(
                        color: Ybox.accent.withOpacity(0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.upload_file_rounded,
                          color: Ybox.accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _fileName ?? 'Choose an .m3u file…',
                          style: const TextStyle(color: Ybox.textHigh),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(color: Ybox.danger, fontSize: 13)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black),
                    )
                  : const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}
