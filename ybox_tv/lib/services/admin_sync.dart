import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import 'platform_info.dart';

/// v3: cloud link to the admin fleet (Firestore).
///
/// - realtime listener on `playlists` (changes apply instantly, anywhere)
/// - device presence: upsert of `devices/{deviceId}` on start/login + every
///   60s heartbeat while the app is running
/// - [syncNow] forces a server round-trip for profile + playlists
class AdminSync {
  static const _kDeviceId = 'ybox.deviceId';
  static const appVersion = '2.4.6';
  static const heartbeatInterval = Duration(seconds: 60);

  final _db = FirebaseFirestore.instance;

  late String deviceId;
  bool connected = false;
  Timer? _heartbeat;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _playlistSub;

  String? _cachedPublicIp;
  DateTime? _publicIpAt;

  /// Declarative apply: the complete list of admin playlists visible to this
  /// user right now (already filtered by target/active).
  final Future<void> Function(List<AdminPlaylistDoc> docs) onPlaylists;
  final void Function()? onStatusChanged;

  /// Username of the signed-in user ('' when signed out).
  final String Function()? usernameProvider;

  /// Auth uid of the signed-in user (null when signed out).
  final String? Function()? uidProvider;

  AdminSync({
    required this.onPlaylists,
    this.onStatusChanged,
    this.usernameProvider,
    this.uidProvider,
  });

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_kDeviceId);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await prefs.setString(_kDeviceId, id);
    }
    deviceId = id;
  }

  /// Starts (or restarts) the cloud link. Call after login and on app start
  /// when a session exists.
  void start() {
    stop();
    if (uidProvider?.call() == null) return; // not signed in
    _listenPlaylists();
    _heartbeat = Timer.periodic(heartbeatInterval, (_) => _presence());
    unawaited(_presence());
  }

  void stop() {
    _heartbeat?.cancel();
    _heartbeat = null;
    _playlistSub?.cancel();
    _playlistSub = null;
  }

  void dispose() => stop();

  String get _username => usernameProvider?.call() ?? '';

  void _listenPlaylists() {
    _playlistSub?.cancel();
    _playlistSub = _db.collection('playlists').snapshots().listen(
      (snap) {
        _setConnected(!snap.metadata.isFromCache);
        final me = _username;
        final docs = <AdminPlaylistDoc>[];
        for (final d in snap.docs) {
          final data = d.data();
          if (!AdminPlaylistDoc.targetsUser(data['targets'], me)) continue;
          final doc = AdminPlaylistDoc.fromMap(d.id, data);
          if (!doc.active) continue;
          docs.add(doc);
        }
        unawaited(onPlaylists(docs));
      },
      onError: (_) => _setConnected(false),
    );
  }

  /// Upserts this device's presence document.
  Future<void> _presence({String? watching}) async {
    final uid = uidProvider?.call();
    if (uid == null) return;
    try {
      await _db.collection('devices').doc(deviceId).set({
        'name': hostname(),
        'platform': platformName(),
        'model': platformVersion(),
        'appVersion': appVersion,
        'publicIp': await _publicIp(),
        'localIp': await localIp(),
        'username': _username,
        'uid': uid,
        'lastSeen': DateTime.now().millisecondsSinceEpoch,
        if (watching != null) 'watching': watching,
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 10));
      _setConnected(true);
    } catch (_) {
      _setConnected(false);
    }
  }

  /// Reports what's currently playing (shown on the admin dashboard).
  Future<void> reportWatching(String title) => _presence(watching: title);

  /// Manual sync: force server reads + a fresh heartbeat. Returns true when
  /// the cloud was reached.
  Future<bool> syncNow() async {
    var ok = false;
    try {
      await _db
          .collection('playlists')
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));
      ok = true;
    } catch (_) {}
    await _presence();
    _setConnected(ok || connected);
    return connected;
  }

  void _setConnected(bool v) {
    if (connected != v) {
      connected = v;
      onStatusChanged?.call();
    }
  }

  Future<String> _publicIp() async {
    final cached = _cachedPublicIp;
    if (cached != null &&
        _publicIpAt != null &&
        DateTime.now().difference(_publicIpAt!) <
            const Duration(minutes: 10)) {
      return cached;
    }
    try {
      final res = await http
          .get(Uri.parse('https://api.ipify.org?format=text'),
              headers: {'User-Agent': 'YBOXTV/2.0'})
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        _cachedPublicIp = res.body.trim();
        _publicIpAt = DateTime.now();
        return _cachedPublicIp!;
      }
    } catch (_) {}
    return _cachedPublicIp ?? '';
  }
}
