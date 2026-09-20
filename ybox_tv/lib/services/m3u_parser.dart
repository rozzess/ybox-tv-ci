import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/models.dart';
import 'm3u_file_io.dart' if (dart.library.html) 'm3u_file_web.dart';
import 'web_proxy.dart';

/// Parses M3U / M3U8 playlists into [Channel]s.
class M3uParser {
  static final _attrRe = RegExp(r'([a-zA-Z0-9\-]+)="([^"]*)"');

  /// Bodies past this are refused — parsing needs several times the body
  /// size in RAM, and panels serve full M3U dumps of 100+ MB.
  static const maxBytes = 25 * 1024 * 1024;

  static Never _tooBig(int bytes) => throw Exception(
      'Playlist is over ${(bytes / (1024 * 1024)).round()} MB — too big to '
      'load on a device. If this is an Xtream get.php link, add the account '
      'as Xtream Codes instead.');

  /// Streams the download so [onProgress] can report received/total bytes
  /// (total is 0 when the server sends no Content-Length).
  static Future<List<Channel>> fromUrl(String url,
      {void Function(int received, int total)? onProgress}) async {
    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(WebProxy.apply(url.trim())));
      req.headers['User-Agent'] = 'IPTVSmartersPlayer';
      final res =
          await client.send(req).timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) {
        throw Exception('Playlist URL returned HTTP ${res.statusCode}');
      }
      final total = res.contentLength ?? 0;
      if (total > maxBytes) _tooBig(total);
      final bytes = BytesBuilder(copy: false);
      await for (final chunk
          in res.stream.timeout(const Duration(seconds: 60))) {
        bytes.add(chunk);
        if (bytes.length > maxBytes) _tooBig(bytes.length);
        onProgress?.call(bytes.length, total);
      }
      return parseAsync(utf8.decode(bytes.takeBytes(), allowMalformed: true));
    } finally {
      client.close();
    }
  }

  static Future<List<Channel>> fromFile(String path) async {
    final content = await readFileAsString(path);
    return parseAsync(content);
  }

  /// [parse] on a background isolate — a big M3U body parsed on the UI
  /// isolate freezes weak devices (TV boxes) long enough to trigger ANR.
  static Future<List<Channel>> parseAsync(String content) =>
      compute(parse, content);

  static List<Channel> parse(String content) {
    final lines = content.split(RegExp(r'\r?\n'));
    final channels = <Channel>[];
    String? pendingExtinf;
    var index = 0;

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#EXTINF')) {
        pendingExtinf = line;
      } else if (!line.startsWith('#')) {
        if (pendingExtinf != null) {
          channels.add(_entry(pendingExtinf, line, index++));
          pendingExtinf = null;
        }
      }
    }
    return channels;
  }

  static Channel _entry(String extinf, String url, int index) {
    final attrs = <String, String>{};
    for (final m in _attrRe.allMatches(extinf)) {
      attrs[m.group(1)!.toLowerCase()] = m.group(2)!;
    }
    final commaIdx = extinf.lastIndexOf(',');
    var name = commaIdx >= 0 && commaIdx < extinf.length - 1
        ? extinf.substring(commaIdx + 1).trim()
        : (attrs['tvg-name'] ?? 'Channel $index');
    if (name.isEmpty) name = attrs['tvg-name'] ?? 'Channel $index';

    final group = (attrs['group-title']?.trim().isNotEmpty ?? false)
        ? attrs['group-title']!.trim()
        : 'Other';
    final logo = attrs['tvg-logo'];
    final type = _classify(url, group);

    return Channel(
      id: 'm3u_${index}_${url.hashCode}',
      name: name,
      logoUrl: (logo == null || logo.isEmpty) ? null : logo,
      group: group,
      streamUrl: url,
      type: type,
    );
  }

  static ContentType _classify(String url, String group) {
    final u = url.toLowerCase();
    final g = group.toLowerCase();
    if (u.contains('/series/') || g.contains('series')) {
      return ContentType.series;
    }
    final looksVod = u.contains('/movie/') ||
        u.endsWith('.mp4') ||
        u.endsWith('.mkv') ||
        u.endsWith('.avi') ||
        u.endsWith('.mov');
    if (looksVod || g.contains('movie') || g.contains('vod') || g.contains('film')) {
      return ContentType.movie;
    }
    return ContentType.live;
  }
}
