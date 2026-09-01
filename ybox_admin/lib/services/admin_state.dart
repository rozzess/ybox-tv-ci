import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/x2005_accounts.dart';
import '../models/models.dart';
import 'auth_service.dart';
import 'keep_alive.dart';

/// App-wide singleton state — realtime Firestore streams for the whole fleet
/// (SPEC 6.3). Attached after an admin signs in; detached on sign-out.
class AdminState extends ChangeNotifier {
  AdminState._();
  static final AdminState instance = AdminState._();

  final KeepAlive keepAlive = KeepAlive();
  final _uuid = const Uuid();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  YUser? admin; // signed-in admin profile
  bool attached = false;
  bool cloudOk = false;

  List<Device> devices = [];
  List<PlaylistEntry> playlists = [];
  List<YUser> users = [];
  List<Conversation> conversations = [];

  /// Quick-pick accounts served from Firestore (x2005/accounts). CI-built
  /// admin IPAs ship with an empty bundled list — the real dump never goes
  /// to the public mirror repo — so the cloud copy is what fills the picker.
  List<X2005Account> x2005Cloud = [];

  /// Bundled dump merged with the cloud copy, deduped by server+user+pass.
  /// Locally-built admins carry the full bundle; mirror-built IPAs start
  /// empty and are filled by [x2005Cloud] once Firestore connects.
  List<X2005Account> get x2005All {
    final seen = <String>{};
    final out = <X2005Account>[];
    for (final a in [...x2005Accounts, ...x2005Cloud]) {
      if (seen.add('${a.server}|${a.username}|${a.password}')) out.add(a);
    }
    return out;
  }

  final List<StreamSubscription> _subs = [];
  Timer? _relabelTimer;

  String get projectId => Firebase.app().options.projectId;
  int get onlineDeviceCount => devices.where((d) => d.online).length;
  int get activeSubCount =>
      users.where((u) => !u.isAdmin && u.subscriptionActive).length;
  int get unreadChats =>
      conversations.fold(0, (total, c) => total + c.unreadByAdmin);
  bool get backgroundKeepAlive => keepAlive.active;

  /// Called on app start: if a session exists and is an admin, attach streams.
  Future<bool> tryRestoreSession() async {
    final user = AdminAuth.currentUser;
    if (user == null) return false;
    try {
      final profile = await AdminAuth.loadProfile(user.uid);
      if (profile == null || !profile.isAdmin) {
        await AdminAuth.signOut();
        return false;
      }
      await onSignedIn(profile);
      return true;
    } catch (_) {
      // Offline with a cached session — trust it; streams serve from cache.
      admin = YUser(uid: user.uid, username: 'admin', role: 'admin');
      await onSignedIn(admin!);
      return true;
    }
  }

  Future<void> onSignedIn(YUser profile) async {
    admin = profile;
    _attachStreams();
    unawaited(keepAlive.start());
    notifyListeners();
  }

  Future<void> signOut() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    _relabelTimer?.cancel();
    await keepAlive.stop();
    await AdminAuth.signOut();
    admin = null;
    attached = false;
    cloudOk = false;
    devices = [];
    playlists = [];
    users = [];
    conversations = [];
    x2005Cloud = [];
    notifyListeners();
  }

  void _attachStreams() {
    if (attached) return;
    attached = true;

    _subs.add(_db.collection('users').snapshots().listen((snap) {
      users = snap.docs.map((d) => YUser.fromDoc(d.id, d.data())).toList()
        ..sort((a, b) => a.username.compareTo(b.username));
      _serverEvent(snap.metadata.isFromCache);
    }, onError: (_) => _cloudDown()));

    _subs.add(_db.collection('devices').snapshots().listen((snap) {
      devices = snap.docs.map((d) => Device.fromDoc(d.id, d.data())).toList()
        ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
      _serverEvent(snap.metadata.isFromCache);
    }, onError: (_) => _cloudDown()));

    _subs.add(_db.collection('playlists').snapshots().listen((snap) {
      playlists =
          snap.docs.map((d) => PlaylistEntry.fromDoc(d.id, d.data())).toList()
            ..sort((a, b) {
              if (a.isBuiltin != b.isBuiltin) return a.isBuiltin ? -1 : 1;
              return b.updatedAt.compareTo(a.updatedAt);
            });
      _serverEvent(snap.metadata.isFromCache);
    }, onError: (_) => _cloudDown()));

    _subs.add(_db
        .collection('chats')
        .orderBy('lastTs', descending: true)
        .snapshots()
        .listen((snap) {
      conversations =
          snap.docs.map((d) => Conversation.fromDoc(d.id, d.data())).toList();
      _serverEvent(snap.metadata.isFromCache);
    }, onError: (_) => _cloudDown()));

    // Quick-pick dump (single doc, admin-read only). Failure is non-fatal —
    // the picker just falls back to whatever is bundled.
    _subs.add(_db.doc('x2005/accounts').snapshots().listen((snap) {
      final data = snap.data();
      final raw = data?['json'];
      if (raw is! String || raw.isEmpty) return;
      try {
        final list = (jsonDecode(raw) as List)
            .cast<Map<String, dynamic>>()
            .map((m) => X2005Account(
                  m['server'] as String? ?? '',
                  m['username'] as String? ?? '',
                  m['password'] as String? ?? '',
                  m['expiry'] as String? ?? '',
                ))
            .toList(growable: false);
        x2005Cloud = list;
        notifyListeners();
      } catch (_) {
        // Malformed doc — keep whatever we had.
      }
    }, onError: (_) {}));

    // Re-render periodically so "online" dots and "Xm ago" labels stay fresh.
    _relabelTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => notifyListeners());
  }

  void _serverEvent(bool fromCache) {
    if (!fromCache) cloudOk = true;
    notifyListeners();
  }

  void _cloudDown() {
    cloudOk = false;
    notifyListeners();
  }

  // ------------------------------------------------------------------- users

  /// Creates a login via a secondary Firebase app so the admin session
  /// survives (SPEC 6.1). Returns null on success, or an error message.
  Future<String?> addUser(
    String username,
    String password, {
    String name = '',
    String phone = '',
    String email = '',
  }) async {
    final uname = username.trim().toLowerCase();
    if (!AdminAuth.usernamePattern.hasMatch(uname)) {
      return 'Username: 3–24 lowercase letters, digits, . _ -';
    }
    if (password.length < 6) return 'Password must be 6+ characters';

    try {
      final taken = await _db.collection('usernames').doc(uname).get();
      if (taken.exists) return 'Username already taken';

      FirebaseApp app2;
      try {
        app2 = Firebase.app('userCreator');
      } catch (_) {
        app2 = await Firebase.initializeApp(
          name: 'userCreator',
          options: Firebase.app().options,
        );
      }
      final auth2 = fb.FirebaseAuth.instanceFor(app: app2);
      final cred = await auth2.createUserWithEmailAndPassword(
        email: AdminAuth.emailFor(uname),
        password: password,
      );
      final uid = cred.user!.uid;
      await auth2.signOut();

      // Docs are written by the ADMIN session (rules: isAdmin()).
      await _db.collection('users').doc(uid).set({
        'username': uname,
        'name': name.trim(),
        'phone': phone.trim(),
        'email': email.trim(),
        'role': 'user',
        'origin': 'admin',
        'active': true,
        'subExpiry': 0,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'createdBy': admin?.username ?? 'admin',
      });
      await _db.collection('usernames').doc(uname).set({'uid': uid});
      return null;
    } on fb.FirebaseAuthException catch (e) {
      return AdminAuth.friendlyAuthError(e);
    } catch (e) {
      return 'Could not create user: $e';
    }
  }

  Future<void> setUserActive(String uid, bool active) =>
      _db.collection('users').doc(uid).update({'active': active});

  /// Grants a subscription of [durationMs].
  /// extend=false replaces the current expiry (now + duration) so the
  /// duration can also be shortened; extend=true adds on top of the later
  /// of now or the current expiry. Returns the new expiry (epoch ms).
  Future<int> grantSubscription(String uid, int durationMs,
      {required bool extend}) async {
    var base = DateTime.now().millisecondsSinceEpoch;
    if (extend) {
      final current = users
          .firstWhere((u) => u.uid == uid,
              orElse: () => const YUser(uid: '', username: ''))
          .subExpiry;
      if (current > base) base = current;
    }
    final expiry = base + durationMs;
    await _db.collection('users').doc(uid).update({'subExpiry': expiry});
    return expiry;
  }

  Future<void> revokeSubscription(String uid) =>
      _db.collection('users').doc(uid).update({'subExpiry': 0});

  /// Removes the profile + username registry entry. The Auth credential
  /// itself can't be deleted from a client — deactivating is the
  /// recommended way to lock someone out.
  Future<void> deleteUser(YUser user) async {
    await _db.collection('users').doc(user.uid).delete();
    if (user.username.isNotEmpty) {
      await _db.collection('usernames').doc(user.username).delete();
    }
  }

  // --------------------------------------------------------------- playlists

  Future<void> saveXtreamPlaylist({
    String? id,
    required String name,
    required String server,
    required String username,
    required String password,
    required Object targets,
    int expiresAt = 0,
  }) {
    final docId = id ?? _uuid.v4();
    return _db.collection('playlists').doc(docId).set({
      'kind': 'xtream',
      'name': name,
      'server': server,
      'username': username,
      'password': password,
      'url': '',
      'replaceBuiltin': docId == 'builtin',
      'targets': targets,
      'expiresAt': expiresAt,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'active': true,
    }, SetOptions(merge: true));
  }

  /// Parses an Xtream `get.php` M3U link into its account parts, or null
  /// when [url] isn't one.
  static ({String server, String username, String password})? parseGetPhp(
      String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.path.toLowerCase().endsWith('get.php')) {
      return null;
    }
    final username = uri.queryParameters['username'] ?? '';
    final password = uri.queryParameters['password'] ?? '';
    if (uri.host.isEmpty || username.isEmpty || password.isEmpty) return null;
    final scheme = uri.scheme.isEmpty ? 'http' : uri.scheme;
    final server = uri.hasPort
        ? '$scheme://${uri.host}:${uri.port}'
        : '$scheme://${uri.host}';
    return (server: server, username: username, password: password);
  }

  Future<void> saveM3uPlaylist({
    String? id,
    required String name,
    required String url,
    required Object targets,
    int expiresAt = 0,
  }) {
    // Xtream get.php links are pushed as Xtream accounts: players use the
    // JSON API instead of downloading a full M3U dump (often 100+ MB), which
    // devices cannot parse — channels would never load.
    final xt = parseGetPhp(url);
    if (xt != null) {
      return saveXtreamPlaylist(
        id: id,
        name: name,
        server: xt.server,
        username: xt.username,
        password: xt.password,
        targets: targets,
        expiresAt: expiresAt,
      );
    }
    final docId = id ?? _uuid.v4();
    return _db.collection('playlists').doc(docId).set({
      'kind': 'm3u',
      'name': name,
      'server': '',
      'username': '',
      'password': '',
      'url': url,
      'replaceBuiltin': false,
      'targets': targets,
      'expiresAt': expiresAt,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'active': true,
    }, SetOptions(merge: true));
  }

  /// Stores the m3u body inline in the doc — players parse it directly, no
  /// hosting needed. Caller must enforce the Firestore doc size limit.
  Future<void> saveM3uFilePlaylist({
    String? id,
    required String name,
    required String content,
    required Object targets,
    int expiresAt = 0,
  }) {
    final docId = id ?? _uuid.v4();
    return _db.collection('playlists').doc(docId).set({
      'kind': 'm3ufile',
      'name': name,
      'server': '',
      'username': '',
      'password': '',
      'url': '',
      'content': content,
      'replaceBuiltin': false,
      'targets': targets,
      'expiresAt': expiresAt,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'active': true,
    }, SetOptions(merge: true));
  }

  /// Doc delete — every targeted player removes it within a snapshot tick.
  Future<void> deletePlaylist(String id) =>
      _db.collection('playlists').doc(id).delete();

  // ----------------------------------------------------------------- devices

  Future<void> removeDevice(String deviceId) =>
      _db.collection('devices').doc(deviceId).delete();

  // -------------------------------------------------------------------- chat

  Stream<List<ChatMessage>> threadStream(String uid, String username) {
    return _db
        .collection('chats')
        .doc(uid)
        .collection('messages')
        .orderBy('ts')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ChatMessage.fromDoc(d.id, d.data(), username: username))
            .toList());
  }

  Future<void> sendAdminMessage(String uid, String username, String text) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final thread = _db.collection('chats').doc(uid);
    await thread.collection('messages').add({
      'fromAdmin': true,
      'text': text,
      'ts': now,
    });
    await thread.set({
      'username': username,
      'lastMessage': text,
      'lastFromAdmin': true,
      'lastTs': now,
      'unreadByUser': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  Future<void> markThreadRead(String uid) => _db
      .collection('chats')
      .doc(uid)
      .set({'unreadByAdmin': 0}, SetOptions(merge: true));

  /// Fleet-wide search: scans the most recent messages of every thread
  /// (client-side, recent window per SPEC 6.3) matching text or username.
  Future<List<ChatMessage>> searchMessages(String query) async {
    final q = query.toLowerCase();
    final results = <ChatMessage>[];
    for (final convo in conversations) {
      final snap = await _db
          .collection('chats')
          .doc(convo.uid)
          .collection('messages')
          .orderBy('ts', descending: true)
          .limit(200)
          .get();
      for (final doc in snap.docs) {
        final msg =
            ChatMessage.fromDoc(doc.id, doc.data(), username: convo.username);
        if (msg.text.toLowerCase().contains(q) ||
            convo.username.toLowerCase().contains(q)) {
          results.add(msg);
        }
      }
    }
    results.sort((a, b) => b.ts.compareTo(a.ts));
    return results;
  }

  // --------------------------------------------------------------- keepalive

  Future<void> setKeepAlive(bool on) async {
    if (on) {
      await keepAlive.start();
    } else {
      await keepAlive.stop();
    }
    notifyListeners();
  }
}
