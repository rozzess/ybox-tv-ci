import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// Persists playlists + active selection. Guarantees the builtin playlist
/// always exists (its credentials may be overridden by an admin push).
class PlaylistStore {
  static const _kPlaylists = 'ybox.playlists';
  static const _kActive = 'ybox.activePlaylist';

  // Credentials come from --dart-define(-from-file) so they never live in
  // source (the CI mirror repo is public). Local/CI builds pass
  // builtin.json (gitignored / GH secret). A build without them still
  // works: the admin's replaceBuiltin playlist doc fills the credentials
  // in on the first cloud sync after login.
  static const defaultBuiltin = Playlist(
    id: Playlist.builtinId,
    name: 'YBOX TV',
    kind: PlaylistKind.xtream,
    server: String.fromEnvironment('YBOX_BUILTIN_SERVER'),
    username: String.fromEnvironment('YBOX_BUILTIN_USERNAME'),
    password: String.fromEnvironment('YBOX_BUILTIN_PASSWORD'),
  );

  Future<List<Playlist>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPlaylists);
    var list = raw == null ? <Playlist>[] : Playlist.decodeList(raw);
    if (!list.any((p) => p.isBuiltin)) {
      list = [defaultBuiltin, ...list];
      await save(list);
    }
    return list;
  }

  Future<void> save(List<Playlist> playlists) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPlaylists, Playlist.encodeList(playlists));
  }

  Future<String> loadActiveId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kActive) ?? Playlist.builtinId;
  }

  Future<void> saveActiveId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kActive, id);
  }
}
