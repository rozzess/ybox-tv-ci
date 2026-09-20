import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// "Continue watching" — keeps the last 10 played items with position.
class RecentStore {
  static const _key = 'ybox.recents';
  static const _max = 10;

  List<RecentEntry> _cache = [];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      _cache = (jsonDecode(raw) as List)
          .map((e) => RecentEntry.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      _cache = [];
    }
  }

  List<RecentEntry> get entries => List.unmodifiable(_cache);

  int? positionFor(String channelId) {
    for (final e in _cache) {
      if (e.channel.id == channelId) return e.positionMs;
    }
    return null;
  }

  Future<void> record(Channel channel, int positionMs) async {
    _cache.removeWhere((e) => e.channel.id == channel.id);
    _cache.insert(
      0,
      RecentEntry(
        channel: channel,
        positionMs: positionMs,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    if (_cache.length > _max) _cache = _cache.sublist(0, _max);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(_cache.map((e) => e.toJson()).toList()));
  }
}
