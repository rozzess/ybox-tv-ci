import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/admin_state.dart';
import '../../theme.dart';
import '../widgets/x2005_picker.dart';
import '../widgets/ybox_widgets.dart';

/// Add/edit sheet for Xtream accounts and M3U playlists, with a target
/// selector (all users or specific users) and an optional expiry (SPEC 6.2).
Future<void> showPlaylistEditSheet(
  BuildContext context, {
  PlaylistEntry? existing,
  String kind = 'xtream',
}) {
  return showYSheet(
    context,
    _PlaylistEditForm(existing: existing, kind: existing?.kind ?? kind),
  );
}

class _PlaylistEditForm extends StatefulWidget {
  final PlaylistEntry? existing;
  final String kind;

  const _PlaylistEditForm({this.existing, required this.kind});

  @override
  State<_PlaylistEditForm> createState() => _PlaylistEditFormState();
}

class _PlaylistEditFormState extends State<_PlaylistEditForm> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _server =
      TextEditingController(text: widget.existing?.server ?? '');
  late final TextEditingController _username =
      TextEditingController(text: widget.existing?.username ?? '');
  late final TextEditingController _password =
      TextEditingController(text: widget.existing?.password ?? '');
  late final TextEditingController _url =
      TextEditingController(text: widget.existing?.url ?? '');

  bool _targetAll = true;
  final Set<String> _selectedUsers = {};
  String? _expiryKey; // null = keep existing / never
  bool _clearExpiry = false;
  int? _serverExpiry; // absolute expiry picked from the X2005 list
  String? _error;
  bool _saving = false;

  // Picked m3u file (kind 'm3ufile').
  String? _pickedFileName;
  String? _pickedContent;

  bool get _isXtream => widget.kind == 'xtream';
  bool get _isFile => widget.kind == 'm3ufile';
  bool get _isBuiltin => widget.existing?.isBuiltin ?? false;

  /// Firestore caps documents at 1 MiB — leave headroom for the other fields.
  static const _maxContentBytes = 900 * 1024;

  Future<void> _pickFile() async {
    setState(() => _error = null);
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;
    if (bytes.length > _maxContentBytes) {
      setState(() => _error =
          'File is ${(bytes.length / 1024).round()} KB — max 900 KB. '
          'Host bigger playlists as an M3U URL instead.');
      return;
    }
    final String content;
    try {
      content = utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      setState(() => _error = 'Could not read that file as text');
      return;
    }
    if (!content.contains('#EXTINF')) {
      setState(() => _error =
          'That doesn\'t look like an M3U playlist (no #EXTINF entries)');
      return;
    }
    setState(() {
      _pickedFileName = file.name;
      _pickedContent = content;
      if (_name.text.trim().isEmpty) {
        _name.text = file.name.replaceAll(RegExp(r'\.m3u8?$'), '');
      }
    });
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null && !existing.targetsAll) {
      _targetAll = false;
      _selectedUsers.addAll(existing.targetUsernames);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _server.dispose();
    _username.dispose();
    _password.dispose();
    _url.dispose();
    super.dispose();
  }

  /// Pre-fills the Xtream fields from a bundled X2005 account.
  Future<void> _pickFromX2005() async {
    final account = await showX2005Picker(context);
    if (account == null || !mounted) return;
    final expiry = account.expiryDate;
    setState(() {
      _name.text = account.hostLabel;
      _server.text = account.server;
      _username.text = account.username;
      _password.text = account.password;
      _serverExpiry = expiry?.millisecondsSinceEpoch;
      _expiryKey = null;
      _clearExpiry = false;
      _error = null;
    });
  }

  int _resolveExpiry() {
    if (_serverExpiry != null) return _serverExpiry!;
    if (_clearExpiry) return 0;
    if (_expiryKey != null) {
      return DateTime.now().millisecondsSinceEpoch +
          (SubDurations.all[_expiryKey] ?? 0);
    }
    return widget.existing?.expiresAt ?? 0;
  }

  Future<void> _save() async {
    final state = AdminState.instance;
    setState(() => _error = null);

    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    if (_isXtream &&
        (_server.text.trim().isEmpty ||
            _username.text.trim().isEmpty ||
            _password.text.trim().isEmpty)) {
      setState(() => _error = 'Server, username and password are required');
      return;
    }
    if (!_isXtream && !_isFile && _url.text.trim().isEmpty) {
      setState(() => _error = 'M3U URL is required');
      return;
    }
    if (_isFile &&
        _pickedContent == null &&
        (widget.existing?.content.isEmpty ?? true)) {
      setState(() => _error = 'Pick an M3U file first');
      return;
    }
    if (!_targetAll && _selectedUsers.isEmpty) {
      setState(() => _error = 'Pick at least one target user');
      return;
    }

    setState(() => _saving = true);
    final Object targets =
        _targetAll ? 'all' : _selectedUsers.toList(growable: false);
    final expiresAt = _resolveExpiry();
    try {
      if (_isXtream) {
        await state.saveXtreamPlaylist(
          id: widget.existing?.id,
          name: _name.text.trim(),
          server: _server.text.trim(),
          username: _username.text.trim(),
          password: _password.text.trim(),
          targets: targets,
          expiresAt: expiresAt,
        );
      } else if (_isFile) {
        await state.saveM3uFilePlaylist(
          id: widget.existing?.id,
          name: _name.text.trim(),
          content: _pickedContent ?? widget.existing!.content,
          targets: targets,
          expiresAt: expiresAt,
        );
      } else {
        await state.saveM3uPlaylist(
          id: widget.existing?.id,
          name: _name.text.trim(),
          url: _url.text.trim(),
          targets: targets,
          expiresAt: expiresAt,
        );
      }
    } catch (e) {
      setState(() {
        _saving = false;
        _error = 'Could not save: $e';
      });
      return;
    }
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved — live on all targeted devices.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = AdminState.instance.users.where((u) => !u.isAdmin).toList();
    final existingExpiry = widget.existing?.expiresAt ?? 0;
    final title = widget.existing == null
        ? (_isXtream
            ? 'Add Xtream account'
            : _isFile
                ? 'Add M3U file'
                : 'Add M3U playlist')
        : (_isBuiltin
            ? 'Edit built-in account'
            : 'Edit ${widget.existing!.name}');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: YText.section),
        if (_isBuiltin) ...[
          const SizedBox(height: YSpace.xs),
          Text(
            'This is the account baked into every player. Saving new '
            'credentials here replaces them on all devices instantly.',
            style: YText.caption,
          ),
        ],
        const SizedBox(height: YSpace.l),
        YTextField(controller: _name, label: 'Display name'),
        if (_isXtream) ...[
          YTextField(
            controller: _server,
            label: 'Server (http://host:port)',
            keyboardType: TextInputType.url,
          ),
          YTextField(controller: _username, label: 'Username'),
          YTextField(controller: _password, label: 'Password'),
          if (widget.existing == null) ...[
            const SizedBox(height: YSpace.xs),
            Text('Quick-pick from bundled server list', style: YText.caption),
            const SizedBox(height: YSpace.s),
            YSecondaryButton(
              label:
                  'Choose X2005 account (${AdminState.instance.x2005All.length})…',
              icon: Icons.list_alt_outlined,
              onPressed: _pickFromX2005,
            ),
            const SizedBox(height: YSpace.m),
          ],
        ] else if (_isFile) ...[
          YSecondaryButton(
            label: _pickedFileName ?? 'Choose .m3u file',
            icon: Icons.upload_file,
            onPressed: _pickFile,
          ),
          const SizedBox(height: YSpace.s),
          Text(
            _pickedContent != null
                ? '${_pickedFileName ?? 'File'} — '
                    '${(_pickedContent!.length / 1024).round()} KB, ready to push.'
                : (widget.existing?.content.isNotEmpty ?? false)
                    ? 'Keeping the current file '
                        '(${(widget.existing!.content.length / 1024).round()} KB). '
                        'Pick a new one to replace it.'
                    : 'The file is stored in the cloud and reaches every '
                        'targeted device — no hosting needed. Max 900 KB.',
            style: YText.caption,
          ),
          const SizedBox(height: YSpace.s),
        ] else
          YTextField(
            controller: _url,
            label: 'M3U URL',
            keyboardType: TextInputType.url,
          ),
        const SizedBox(height: YSpace.s),
        Text('Playlist expiry', style: YText.caption),
        const SizedBox(height: YSpace.s),
        Wrap(
          spacing: YSpace.s,
          runSpacing: YSpace.s,
          children: [
            if (_serverExpiry != null)
              ChoiceChip(
                label: Text(
                  'Server: ${SubDurations.dateLabel(_serverExpiry!)}',
                ),
                selected: true,
                selectedColor: YColors.accentSoft(0.25),
                onSelected: (_) => setState(() {
                  _serverExpiry = null;
                  _expiryKey = null;
                  _clearExpiry = false;
                }),
              ),
            ChoiceChip(
              label: Text(existingExpiry > 0 && !_clearExpiry &&
                      _expiryKey == null &&
                      _serverExpiry == null
                  ? 'Keep (${widget.existing!.expiryLabel})'
                  : 'Never'),
              selected: _expiryKey == null && !_clearExpiry
                  ? _serverExpiry == null && existingExpiry == 0
                  : _clearExpiry,
              selectedColor: YColors.accentSoft(0.25),
              onSelected: (_) => setState(() {
                _expiryKey = null;
                _clearExpiry = true;
                _serverExpiry = null;
              }),
            ),
            for (final key in SubDurations.all.keys)
              ChoiceChip(
                label: Text(SubDurations.labels[key]!),
                selected: _expiryKey == key,
                selectedColor: YColors.accentSoft(0.25),
                onSelected: (_) => setState(() {
                  _expiryKey = key;
                  _clearExpiry = false;
                  _serverExpiry = null;
                }),
              ),
          ],
        ),
        if (!_isBuiltin) ...[
          const SizedBox(height: YSpace.m),
          Text('Send to', style: YText.caption),
          const SizedBox(height: YSpace.s),
          Row(
            children: [
              ChoiceChip(
                label: const Text('All users'),
                selected: _targetAll,
                selectedColor: YColors.accentSoft(0.25),
                onSelected: (_) => setState(() => _targetAll = true),
              ),
              const SizedBox(width: YSpace.s),
              ChoiceChip(
                label: const Text('Specific users'),
                selected: !_targetAll,
                selectedColor: YColors.accentSoft(0.25),
                onSelected: (_) => setState(() => _targetAll = false),
              ),
            ],
          ),
          if (!_targetAll) ...[
            const SizedBox(height: YSpace.s),
            if (users.isEmpty)
              Text('No user accounts yet.', style: YText.caption)
            else
              ...users.map(
                (u) => CheckboxListTile(
                  value: _selectedUsers.contains(u.username),
                  dense: true,
                  activeColor: YColors.accent,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    u.username,
                    style: TextStyle(color: YColors.text(0.9), fontSize: 14),
                  ),
                  subtitle: u.name.isEmpty
                      ? null
                      : Text(u.name, style: YText.caption),
                  onChanged: (checked) => setState(() {
                    if (checked == true) {
                      _selectedUsers.add(u.username);
                    } else {
                      _selectedUsers.remove(u.username);
                    }
                  }),
                ),
              ),
          ],
        ],
        if (_error != null) ...[
          const SizedBox(height: YSpace.s),
          Text(
            _error!,
            style: const TextStyle(color: YColors.danger, fontSize: 13),
          ),
        ],
        const SizedBox(height: YSpace.l),
        YPrimaryButton(
          label: _saving ? 'Saving…' : 'Save',
          icon: Icons.check,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}
