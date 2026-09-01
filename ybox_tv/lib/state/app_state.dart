import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../services/admin_sync.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/favorites_store.dart';
import '../services/m3u_parser.dart';
import '../services/playlist_store.dart';
import '../services/recent_store.dart';
import '../services/xtream_api.dart';

/// Central app state (playlists, content, favorites, recents, auth, admin).
class AppState extends ChangeNotifier {
  final playlistStore = PlaylistStore();
  final favorites = FavoritesStore();
  final recents = RecentStore();
  final auth = AuthService();
  final chat = ChatService();
  late final AdminSync adminSync;

  List<Playlist> playlists = [];
  Playlist? active;

  final Map<ContentType, List<Channel>> _items = {};
  final Map<ContentType, List<Group>> _groups = {};
  final Map<ContentType, bool> _loading = {};
  final Map<ContentType, String?> _errors = {};

  // Cache of a full M3U parse shared between the three sections.
  List<Channel>? _m3uAll;
  Future<List<Channel>>? _m3uLoading;

  bool _initialized = false;
  bool _syncing = false;

  /// 0..1 while the selected playlist preloads its sections; null = idle.
  /// Shown as a percentage banner on Home/Playlists.
  double? playlistProgress;
  String playlistStage = '';
  Timer? _progressResetTimer;

  AppState() {
    adminSync = AdminSync(
      onPlaylists: _applyAdminPlaylists,
      onStatusChanged: notifyListeners,
      usernameProvider: () => auth.username ?? '',
      uidProvider: () => auth.uid,
    );
    auth.onProfileChanged = notifyListeners;
    chat.onChanged = notifyListeners;
  }

  bool get initialized => _initialized;

  /// A session is always required — cached sessions work offline.
  bool get needsLogin => !auth.hasSession;

  bool get isAdmin => auth.isAdmin;

  /// Content is gated on an active subscription (admins are never gated).
  bool get subscriptionExpired => !isAdmin && auth.subscriptionExpired;

  Duration get subscriptionRemaining => auth.subscriptionRemaining;
  int get unreadChat => chat.unread;
  bool get syncing => _syncing;

  Future<void> init() async {
    await favorites.load();
    await recents.load();
    await auth.load();
    await adminSync.init();
    playlists = await playlistStore.load();
    final activeId = await playlistStore.loadActiveId();
    active = playlists.firstWhere((p) => p.id == activeId,
        orElse: () => playlists.first);
    _ensureActiveUsable(save: false);
    _startCloud();
    _initialized = true;
    notifyListeners();
  }

  /// Wires the cloud listeners for the signed-in session (no-op signed out).
  void _startCloud() {
    if (!auth.hasSession) return;
    adminSync.start();
    final id = auth.uid;
    if (id != null) {
      chat.attach(uid: id, username: auth.username ?? '');
    }
  }

  /// Manual sync (button): forces a server round-trip for profile +
  /// playlists. Returns true when the cloud was reached.
  Future<bool> syncNow() async {
    if (_syncing) return adminSync.connected;
    _syncing = true;
    notifyListeners();
    final okProfile = await auth.refreshProfile();
    final okSync = await adminSync.syncNow();
    _syncing = false;
    notifyListeners();
    return okProfile || okSync;
  }

  // ---------------------------------------------------------------- content

  List<Channel> itemsOf(ContentType t) => _items[t] ?? const [];
  List<Group> groupsOf(ContentType t) => _groups[t] ?? const [];
  bool isLoading(ContentType t) => _loading[t] ?? false;
  String? errorOf(ContentType t) => _errors[t];

  List<Channel> itemsInGroup(ContentType t, String group) =>
      itemsOf(t).where((c) => c.group == group).toList();

  Future<void> ensureLoaded(ContentType t, {bool force = false}) async {
    // Expired subscription: never load content.
    if (subscriptionExpired) return;
    if (!force && (_items[t] != null || (_loading[t] ?? false))) return;
    final playlist = active;
    if (playlist == null || playlist.isExpired) return;

    _loading[t] = true;
    _errors[t] = null;
    notifyListeners();

    try {
      List<Channel> items;
      if (playlist.kind == PlaylistKind.xtream) {
        final api = XtreamApi.fromPlaylist(playlist);
        items = switch (t) {
          ContentType.live => await api.liveStreams(),
          ContentType.movie => await api.vodStreams(),
          ContentType.series => await api.seriesList(),
        };
      } else {
        final all = await _loadM3u(playlist, force: force);
        items = all.where((c) => c.type == t).toList();
      }
      _items[t] = items;
      _groups[t] = _deriveGroups(items, t);
      _errors[t] = null;
    } catch (e) {
      _errors[t] = e.toString();
    } finally {
      _loading[t] = false;
      notifyListeners();
    }
  }

  Future<List<Channel>> _loadM3u(Playlist p, {bool force = false}) {
    if (!force && _m3uAll != null) return Future.value(_m3uAll!);
    if (!force && _m3uLoading != null) return _m3uLoading!;
    final future = () async {
      final List<Channel> list;
      if (p.content != null && p.content!.isNotEmpty) {
        list = await M3uParser.parseAsync(p.content!);
      } else if (p.kind == PlaylistKind.m3uUrl) {
        list = await M3uParser.fromUrl(p.url ?? '');
      } else {
        list = await M3uParser.fromFile(p.url ?? '');
      }
      _m3uAll = list;
      _m3uLoading = null;
      return list;
    }();
    _m3uLoading = future;
    return future;
  }

  static List<Group> _deriveGroups(List<Channel> items, ContentType t) {
    final counts = <String, int>{};
    for (final c in items) {
      counts[c.group] = (counts[c.group] ?? 0) + 1;
    }
    final names = counts.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return [
      for (final n in names) Group(name: n, type: t, count: counts[n]!)
    ];
  }

  void _clearContent() {
    _items.clear();
    _groups.clear();
    _errors.clear();
    _m3uAll = null;
    _m3uLoading = null;
  }

  Future<XtreamApi?> xtreamForActive() async {
    final p = active;
    if (p == null || p.kind != PlaylistKind.xtream) return null;
    return XtreamApi.fromPlaylist(p);
  }

  // -------------------------------------------------------------- playlists

  /// Playlists that are not past their admin-set expiry.
  List<Playlist> get usablePlaylists =>
      playlists.where((p) => !p.isExpired).toList();

  /// Keeps [active] pointing at a usable playlist, falling back to the
  /// builtin (if usable) or the first usable playlist; null when none are.
  void _ensureActiveUsable({bool save = true}) {
    if (active != null && !active!.isExpired) return;
    final usable = usablePlaylists;
    if (usable.isEmpty) {
      active = null;
      _clearContent();
      return;
    }
    active = usable.firstWhere((p) => p.isBuiltin, orElse: () => usable.first);
    _clearContent();
    if (save) unawaited(playlistStore.saveActiveId(active!.id));
  }

  Future<void> setActive(Playlist p) async {
    if (p.isExpired) return;
    active = p;
    await playlistStore.saveActiveId(p.id);
    _clearContent();
    notifyListeners();
    unawaited(preloadActive());
  }

  void _setLoadProgress(double? value, [String stage = '']) {
    playlistProgress = value;
    playlistStage = stage;
    notifyListeners();
  }

  /// Waits for section [t], even when another caller is already loading it.
  Future<void> _awaitSection(ContentType t) async {
    if (_items[t] != null) return;
    if (_loading[t] ?? false) {
      while (_loading[t] ?? false) {
        await Future.delayed(const Duration(milliseconds: 150));
      }
      return;
    }
    await ensureLoaded(t);
  }

  /// Loads every section of the active playlist up-front, publishing 0–100%
  /// progress while the user keeps browsing.
  Future<void> preloadActive() async {
    final p = active;
    if (p == null || p.isExpired || subscriptionExpired) return;
    _progressResetTimer?.cancel();
    _setLoadProgress(0.02, 'Connecting…');
    try {
      if (p.kind == PlaylistKind.xtream) {
        const stages = [
          (ContentType.live, 'Loading Live TV…', 0.45),
          (ContentType.movie, 'Loading Movies…', 0.75),
          (ContentType.series, 'Loading Series…', 1.0),
        ];
        for (final (type, label, target) in stages) {
          _setLoadProgress(playlistProgress, label);
          await _awaitSection(type);
          if (active?.id != p.id) return; // switched away mid-load
          _setLoadProgress(target, label);
        }
      } else {
        // One m3u body feeds all three sections — progress = download bytes.
        if (_m3uAll == null) {
          if (_m3uLoading != null) {
            _setLoadProgress(0.3, 'Downloading playlist…');
            await _m3uLoading;
          } else if (p.content != null && p.content!.isNotEmpty) {
            _m3uAll = await M3uParser.parseAsync(p.content!);
          } else if (p.kind == PlaylistKind.m3uUrl) {
            _m3uAll = await M3uParser.fromUrl(p.url ?? '',
                onProgress: (received, total) {
              if (total > 0) {
                _setLoadProgress(0.05 + 0.85 * (received / total),
                    'Downloading playlist…');
              } else {
                _setLoadProgress(0.4,
                    'Downloading playlist… ${(received / 1024).round()} KB');
              }
            });
          } else {
            _m3uAll = await M3uParser.fromFile(p.url ?? '');
          }
        }
        if (active?.id != p.id) return;
        _setLoadProgress(0.92, 'Preparing sections…');
        for (final t in ContentType.values) {
          await _awaitSection(t);
        }
      }
    } catch (_) {
      _setLoadProgress(null);
      return;
    }
    if (active?.id != p.id) return;
    _setLoadProgress(1.0, 'Playlist ready');
    _progressResetTimer = Timer(
        const Duration(seconds: 4), () => _setLoadProgress(null));
  }

  Future<void> addPlaylist(Playlist p) async {
    playlists = [...playlists, p];
    await playlistStore.save(playlists);
    notifyListeners();
  }

  Future<void> updatePlaylist(Playlist p) async {
    playlists = [
      for (final existing in playlists) existing.id == p.id ? p : existing
    ];
    await playlistStore.save(playlists);
    if (active?.id == p.id) {
      active = p;
      _clearContent();
    }
    notifyListeners();
  }

  /// Builtin cannot be deleted; deleting the active playlist falls back to it.
  Future<void> deletePlaylist(String id) async {
    if (id == Playlist.builtinId) return;
    playlists = playlists.where((p) => p.id != id).toList();
    await playlistStore.save(playlists);
    if (active?.id == id) {
      await setActive(playlists.firstWhere((p) => p.isBuiltin,
          orElse: () => playlists.first));
    } else {
      notifyListeners();
    }
  }

  Future<void> restoreBuiltin() async {
    playlists = [
      for (final p in playlists)
        p.isBuiltin ? PlaylistStore.defaultBuiltin : p
    ];
    await playlistStore.save(playlists);
    if (active?.isBuiltin ?? false) {
      active = PlaylistStore.defaultBuiltin;
      _clearContent();
    }
    notifyListeners();
  }

  static String newPlaylistId() => const Uuid().v4();

  // -------------------------------------------------------------- favorites

  bool isFavorite(Channel c) => favorites.isFavorite(c);
  List<Channel> favoritesOf(ContentType t) => favorites.of(t);

  Future<bool> toggleFavorite(Channel c) async {
    final added = await favorites.toggle(c);
    notifyListeners();
    return added;
  }

  // ---------------------------------------------------------------- recents

  List<RecentEntry> get continueWatching => recents.entries;

  Future<void> recordRecent(Channel c, int positionMs) async {
    await recents.record(c, positionMs);
    notifyListeners();
  }

  int? resumePositionFor(Channel c) => recents.positionFor(c.id);

  // ------------------------------------------------------------------ admin

  /// Declarative reconcile: [docs] is the complete set of admin playlists
  /// visible to this user. Local `admin_*` playlists not in it are removed;
  /// a doc with replaceBuiltin overwrites the builtin credentials.
  Future<void> _applyAdminPlaylists(List<AdminPlaylistDoc> docs) async {
    var changed = false;
    final wantedIds = <String>{};

    for (final doc in docs) {
      if (doc.replaceBuiltin && doc.kind == PlaylistKind.xtream) {
        final builtinMatches = playlists.where((p) => p.isBuiltin).toList();
        final builtin = builtinMatches.isEmpty ? null : builtinMatches.first;
        if (builtin != null &&
            (builtin.name != doc.name ||
                builtin.server != doc.server ||
                builtin.username != doc.username ||
                builtin.password != doc.password ||
                builtin.expiresAt != doc.expiresAt)) {
          playlists = [
            for (final p in playlists)
              p.isBuiltin
                  ? p.copyWith(
                      name: doc.name,
                      server: doc.server,
                      username: doc.username,
                      password: doc.password,
                      expiresAt: doc.expiresAt,
                    )
                  : p
          ];
          changed = true;
        }
        continue;
      }
      final id = 'admin_${doc.docId}';
      wantedIds.add(id);
      // An "M3U URL" that is really an Xtream get.php link is used through
      // the JSON API instead: full panel M3U bodies can exceed 100 MB, which
      // no device can download and parse (channels never load, nothing plays).
      final xt = doc.kind == PlaylistKind.m3uUrl
          ? XtreamApi.parseGetPhp(doc.url ?? '')
          : null;
      final incoming = Playlist(
        id: id,
        name: doc.name,
        kind: xt != null ? PlaylistKind.xtream : doc.kind,
        server: xt?.server ?? doc.server,
        username: xt?.username ?? doc.username,
        password: xt?.password ?? doc.password,
        url: xt != null ? '' : doc.url,
        content: doc.content,
        expiresAt: doc.expiresAt,
      );
      final idx = playlists.indexWhere((p) => p.id == id);
      if (idx < 0) {
        playlists = [...playlists, incoming];
        changed = true;
      } else if (playlists[idx].toJson().toString() !=
          incoming.toJson().toString()) {
        playlists = [
          for (final p in playlists) p.id == id ? incoming : p
        ];
        changed = true;
      }
    }

    // Remove admin playlists the fleet no longer pushes to this user.
    final before = playlists.length;
    playlists = playlists
        .where((p) => !p.id.startsWith('admin_') || wantedIds.contains(p.id))
        .toList();
    changed = changed || playlists.length != before;

    if (changed) {
      await playlistStore.save(playlists);
      final activeId = active?.id;
      if (activeId != null) {
        active = playlists.firstWhere((p) => p.id == activeId,
            orElse: () => playlists.first);
        _clearContent();
      }
      _ensureActiveUsable();
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    adminSync.stop();
    chat.detach();
    await auth.logout();
    notifyListeners();
  }

  Future<String?> login(String username, String password) async {
    final err = await auth.login(username, password);
    if (err == null) _startCloud();
    notifyListeners();
    return err;
  }

  Future<String?> register({
    required String username,
    required String password,
    required String name,
    required String phone,
    required String email,
  }) async {
    final err = await auth.register(
      user: username,
      password: password,
      fullName: name,
      phone: phone,
      email: email,
    );
    if (err == null) _startCloud();
    notifyListeners();
    return err;
  }

  // ------------------------------------------------------------------- chat

  /// Called when the chat screen opens: mark everything read.
  Future<void> openChatRefresh() async {
    await chat.markAllRead();
    notifyListeners();
  }

  Future<bool> sendChat(String text) async {
    final ok = await chat.send(text);
    notifyListeners();
    return ok;
  }

  Future<bool> clearChat() async {
    final ok = await chat.clear();
    notifyListeners();
    return ok;
  }

  @override
  void dispose() {
    adminSync.dispose();
    super.dispose();
  }
}

/// InheritedNotifier so screens can do `AppScope.of(context)`.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in widget tree');
    return scope!.notifier!;
  }

  /// Read without subscribing (for callbacks).
  static AppState read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in widget tree');
    return scope!.notifier!;
  }
}
