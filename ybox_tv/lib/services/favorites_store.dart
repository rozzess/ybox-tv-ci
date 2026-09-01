import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// Favorites stored separately per section (live / movies / series).
/// Full channel snapshots are stored so the favorites rail renders even
/// before section content has loaded.
class FavoritesStore {
  static String _key(ContentType t) => 'ybox.favorites.${t.key}';

  final Map<ContentType, List<Channel>> _cache = {};

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    for (final t in ContentType.values) {
      final raw = prefs.getString(_key(t));
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key(c.type), jsonEncode(list.map((e) => e.toJson()).toList()));
    return added;
  }
}
