import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// Favorites kept separately per section (live / movies / series) and stored
/// BOTH locally (SharedPreferences, works offline) and in a per-account
/// Firestore doc (`favorites/{uid}`) so the same list follows the user across
/// every platform and app — phone, TV, Windows and web all live-patch each
/// other through the snapshot listener while signed in.
///
/// Full channel snapshots are stored so the favorites rail renders even
/// before section content has loaded.
class FavoritesStore {
  static String _localKey(ContentType t) => 'ybox.favorites.${t.key}';

  static const _cloudCollection = 'favorites';

  /// Firestore field per content section.
  static String _cloudField(ContentType t) {
    return switch (t) {
      ContentType.live => 'live',
      ContentType.movie => 'movie',
      ContentType.series => 'series',
    };
  }

  /// Fired whenever the favorites change (local toggle or a remote patch).
  VoidCallback? onChanged;

  final Map<ContentType, List<Channel>> _cache = {};

  String? _uid;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _cloudSub;
  /// Set once the cloud doc has been read at least once, so a toggle made in
  /// the first moments after login doesn't clobber what's already up there.
  bool _cloudLoaded = false;
  /// Local change that happened before the first cloud read.
  bool _dirty = false;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    for (final t in ContentType.values) {
      final raw = prefs.getString(_localKey(t));
      if (raw == null) {
        _cache[t] = [];
        continue;
      }
      try {
        final list = (jsonDecode(raw) as List)
            .map((e) => Channel.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
        _cache[t] = list;
      } catch (_) {
        _cache[t] = [];
      }
    }
  }

  /// Real-time sync for the signed-in user. Call on login; replaces local
  /// state with the cloud list and then keeps it live.
  void attach(String uid) {
    _uid = uid;
    _cloudSub?.cancel();
    _cloudSub = FirebaseFirestore.instance
        .collection(_cloudCollection)
        .doc(uid)
        .snapshots()
        .listen(_applyCloudSnapshot, onError: (_) {});
  }

  /// Stop cloud sync (sign-out). Local cache stays.
  void detach() {
    _uid = null;
    _cloudSub?.cancel();
    _cloudSub = null;
    _cloudLoaded = false;
    _dirty = false;
  }

  void _applyCloudSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    var changed = false;
    if (snap.exists) {
      final data = snap.data() ?? const {};
      for (final t in ContentType.values) {
        final raw = data[_cloudField(t)];
        if (raw is! List) continue;
        final list = raw
            .where((e) => e is Map)
            .map((e) =>
                Channel.fromJson((e as Map).cast<String, dynamic>()))
            .where((c) => c.id.isNotEmpty)
            .toList();
        if (list.length != _cache[t]?.length || _cache[t] == null) {
          _cache[t] = list;
          changed = true;
        } else {
          final ids = _cache[t]!.map((c) => c.id).toSet();
          if (list.any((c) => !ids.contains(c.id))) {
            _cache[t] = list;
            changed = true;
          }
        }
      }
    } else {
      // Someone (admin reset, or this user cleared) deleted the cloud doc.
      for (final t in ContentType.values) {
        if (_cache[t]?.isNotEmpty ?? false) {
          _cache[t] = [];
          changed = true;
        }
      }
    }
    _cloudLoaded = true;
    if (_dirty) {
      unawaited(_pushCloud());
    }
    if (changed) {
      unawaited(_persistLocal());
      onChanged?.call();
    }
  }

  List<Channel> of(ContentType t) => List.unmodifiable(_cache[t] ?? const []);

  bool isFavorite(Channel c) =>
      (_cache[c.type] ?? const []).any((f) => f.id == c.id);

  /// Returns true if the channel is now a favorite.
  Future<bool> toggle(Channel c) async {
    final list = List<Channel>.from(_cache[c.type] ?? const []);
    final idx = list.indexWhere((f) => f.id == c.id);
    bool added;
    if (idx >= 0) {
      list.removeAt(idx);
      added = false;
    } else {
      list.insert(0, c);
      added = true;
    }
    _cache[c.type] = list;
    await _persistLocal();
    unawaited(_pushCloud());
    onChanged?.call();
    return added;
  }

  Future<void> _persistLocal() async {
    final prefs = await SharedPreferences.getInstance();
    for (final t in ContentType.values) {
      await prefs.setString(
          _localKey(t), jsonEncode(_cache[t]?.map((e) => e.toJson()).toList()));
    }
  }

  /// Push the full per-section lists to `favorites/{uid}` (last-writer-wins).
  Future<void> _pushCloud() async {
    final uid = _uid;
    if (uid == null) return;
    if (!_cloudLoaded) {
      _dirty = true; // replayed right after the first cloud read
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection(_cloudCollection)
          .doc(uid)
          .set({
        for (final t in ContentType.values)
          _cloudField(t): _cache[t]?.map((e) => e.toJson()).toList() ?? [],
      }).timeout(const Duration(seconds: 10));
      _dirty = false;
    } catch (_) {
      // Keep the list local; the next toggle (or next session) retries.
    }
  }
}