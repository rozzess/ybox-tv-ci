import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/models.dart';
import 'web_proxy.dart';

/// Client for Xtream Codes `player_api.php`.
class XtreamApi {
  /// Some panels silently drop requests from unknown clients, so every call
  /// (API + playback) identifies as a common IPTV player.
  static const userAgent = 'IPTVSmartersPlayer';
  static const uaHeaders = {'User-Agent': userAgent};

  /// Live container per platform: ExoPlayer (Android) plays raw MPEG-TS,
  /// everything else — AVPlayer (iOS), the web hls.js player, desktop mpv —
  /// needs HLS. Raw MPEG-TS cannot play in a browser.
  static String get liveExtension {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'ts';
    }
    return 'm3u8';
  }

  final String server; // normalized, no trailing slash, with scheme
  final String username;
  final String password;

  XtreamApi({
    required String server,
    required this.username,
    required this.password,
  }) : server = normalizeServer(server);

  factory XtreamApi.fromPlaylist(Playlist p) => XtreamApi(
        server: p.server ?? '',
        username: p.username ?? '',
        password: p.password ?? '',
      );

  /// Parses an Xtream `get.php` M3U link into its account parts, or null
  /// when [url] isn't one. Panels hand these links out as "M3U URLs", but a
  /// full panel M3U body can run to 100+ MB — far beyond what a device can
  /// download and parse — while the same account works through the JSON API.
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

  static String normalizeServer(String s) {
    var out = s.trim();
    if (out.isEmpty) return out;
    if (!out.startsWith('http://') && !out.startsWith('https://')) {
      out = 'http://$out';
    }
    while (out.endsWith('/')) {
      out = out.substring(0, out.length - 1);
    }
    return out;
  }

  Uri _api(String action) => Uri.parse(WebProxy.apply(
      '$server/player_api.php?username=$username&password=$password&action=$action'));

  Future<dynamic> _getJson(Uri uri, {int retries = 2}) async {
    Object? lastError;
    for (var attempt = 0; attempt <= retries; attempt++) {
      try {
        final res = await http
            .get(uri, headers: uaHeaders)
            .timeout(const Duration(seconds: 20));
        if (res.statusCode != 200) {
          throw XtreamException('Server returned HTTP ${res.statusCode}');
        }
        // Panels return multi-MB JSON for get_live_streams/get_vod_streams —
        // decoding that on the UI isolate freezes weak devices (TV boxes)
        // for seconds and can trip the ANR killer.
        return compute(jsonDecode, res.body);
      } catch (e) {
        lastError = e;
        if (attempt < retries) {
          await Future.delayed(Duration(milliseconds: 400 * (attempt + 1)));
        }
      }
    }
    throw XtreamException(
        lastError is XtreamException ? lastError.message : 'Network error');
  }

  /// Validates the account by hitting the base API endpoint.
  Future<bool> validate() async {
    final data = await _getJson(Uri.parse(WebProxy.apply(
        '$server/player_api.php?username=$username&password=$password')));
    if (data is Map && data['user_info'] is Map) {
      final auth = data['user_info']['auth'];
      return auth == 1 || auth == '1' || auth == true;
    }
    return false;
  }

  /// Live account state — used to explain playback failures (most panels
  /// cap concurrent streams per account; shared accounts hit that cap the
  /// moment another device watches). Null when the panel can't be reached.
  Future<XtreamAccountStatus?> accountStatus() async {
    try {
      final data = await _getJson(
          Uri.parse(WebProxy.apply(
              '$server/player_api.php?username=$username&password=$password')),
          retries: 0);
      if (data is Map && data['user_info'] is Map) {
        final u = data['user_info'] as Map;
        final auth = u['auth'];
        return XtreamAccountStatus(
          authed: auth == 1 || auth == '1' || auth == true,
          status: u['status']?.toString() ?? '',
          activeCons: int.tryParse(u['active_cons']?.toString() ?? '') ?? 0,
          maxConnections:
              int.tryParse(u['max_connections']?.toString() ?? '') ?? 0,
        );
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, String>> _categories(String action) async {
    final data = await _getJson(_api(action));
    final map = <String, String>{};
    if (data is List) {
      for (final e in data) {
        if (e is Map) {
          final id = e['category_id']?.toString() ?? '';
          final name = e['category_name']?.toString() ?? 'Other';
          if (id.isNotEmpty) map[id] = name;
        }
      }
    }
    return map;
  }

  Future<List<Channel>> liveStreams() async {
    final cats = await _categories('get_live_categories');
    final data = await _getJson(_api('get_live_streams'));
    final out = <Channel>[];
    if (data is List) {
      for (final e in data) {
        if (e is! Map) continue;
        final id = e['stream_id']?.toString() ?? '';
        if (id.isEmpty) continue;
        out.add(Channel(
          id: 'live_$id',
          name: e['name']?.toString() ?? 'Channel',
          logoUrl: _emptyToNull(e['stream_icon']?.toString()),
          group: cats[e['category_id']?.toString()] ?? 'Other',
          streamUrl: WebProxy.apply(
              '$server/live/$username/$password/$id.$liveExtension'),
          type: ContentType.live,
        ));
      }
    }
    return out;
  }

  Future<List<Channel>> vodStreams() async {
    final cats = await _categories('get_vod_categories');
    final data = await _getJson(_api('get_vod_streams'));
    final out = <Channel>[];
    if (data is List) {
      for (final e in data) {
        if (e is! Map) continue;
        final id = e['stream_id']?.toString() ?? '';
        if (id.isEmpty) continue;
        final ext = _emptyToNull(e['container_extension']?.toString()) ?? 'mp4';
        out.add(Channel(
          id: 'vod_$id',
          name: e['name']?.toString() ?? 'Movie',
          logoUrl: _emptyToNull(e['stream_icon']?.toString()),
          group: cats[e['category_id']?.toString()] ?? 'Other',
          streamUrl: WebProxy.apply(
              '$server/movie/$username/$password/$id.$ext'),
          type: ContentType.movie,
        ));
      }
    }
    return out;
  }

  Future<List<Channel>> seriesList() async {
    final cats = await _categories('get_series_categories');
    final data = await _getJson(_api('get_series'));
    final out = <Channel>[];
    if (data is List) {
      for (final e in data) {
        if (e is! Map) continue;
        final id = e['series_id']?.toString() ?? '';
        if (id.isEmpty) continue;
        out.add(Channel(
          id: id, // raw series_id, used by seriesInfo()
          name: e['name']?.toString() ?? 'Series',
          logoUrl: _emptyToNull(e['cover']?.toString()),
          group: cats[e['category_id']?.toString()] ?? 'Other',
          streamUrl: '', // open series detail
          type: ContentType.series,
        ));
      }
    }
    return out;
  }

  Future<SeriesInfo> seriesInfo(String seriesId, String name) async {
    final data = await _getJson(Uri.parse(WebProxy.apply(
        '$server/player_api.php?username=$username&password=$password&action=get_series_info&series_id=$seriesId')));
    final seasons = <Season>[];
    String? cover;
    String? plot;
    if (data is Map) {
      final info = data['info'];
      if (info is Map) {
        cover = _emptyToNull(info['cover']?.toString());
        plot = _emptyToNull(info['plot']?.toString());
      }
      final eps = data['episodes'];
      if (eps is Map) {
        final seasonKeys = eps.keys.map((k) => k.toString()).toList()
          ..sort((a, b) =>
              (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));
        for (final sk in seasonKeys) {
          final list = eps[sk];
          if (list is! List) continue;
          final episodes = <Episode>[];
          for (final e in list) {
            if (e is! Map) continue;
            final epId = e['id']?.toString() ?? '';
            if (epId.isEmpty) continue;
            final ext =
                _emptyToNull(e['container_extension']?.toString()) ?? 'mp4';
            final epNum =
                int.tryParse(e['episode_num']?.toString() ?? '') ?? 0;
            String? epInfo;
            final infoMap = e['info'];
            if (infoMap is Map) {
              epInfo = _emptyToNull(infoMap['plot']?.toString());
            }
            episodes.add(Episode(
              id: epId,
              title: e['title']?.toString() ?? 'Episode $epNum',
              streamUrl: WebProxy.apply(
                  '$server/series/$username/$password/$epId.$ext'),
              season: int.tryParse(sk) ?? 0,
              episodeNum: epNum,
              info: epInfo,
            ));
          }
          episodes.sort((a, b) => a.episodeNum.compareTo(b.episodeNum));
          seasons.add(Season(season: int.tryParse(sk) ?? 0, episodes: episodes));
        }
      }
    }
    return SeriesInfo(
        id: seriesId, name: name, cover: cover, plot: plot, seasons: seasons);
  }

  static String? _emptyToNull(String? s) =>
      (s == null || s.isEmpty || s == 'null') ? null : s;
}

class XtreamAccountStatus {
  final bool authed;
  final String status; // 'Active', 'Expired', 'Banned', ...
  final int activeCons;
  final int maxConnections; // 0 = unknown/unlimited

  const XtreamAccountStatus({
    required this.authed,
    required this.status,
    required this.activeCons,
    required this.maxConnections,
  });

  bool get busy => maxConnections > 0 && activeCons >= maxConnections;
}

class XtreamException implements Exception {
  final String message;
  XtreamException(this.message);

  @override
  String toString() => message;
}
