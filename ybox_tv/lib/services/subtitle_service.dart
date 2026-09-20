import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'web_proxy.dart';

/// Default free SubDL API key (subdl.com). The free tier needs no login —
/// just this key — and supports a per-day request quota that is plenty for a
/// single user picking subtitles for movies and shows. Entered once here so
/// downloads work out of the box; it can be overridden in Settings.
const String kDefaultSubtitleApiKey =
    'subdl_aYa8pbIkeBv8DpS-O9aZkok81_IPDFbfQkVrkWJkkZQ';

/// Persisted SubDL preferences + configured state.
class SubtitleSettings {
  static const _kKey = 'subtitle_api_key';
  static const _kLang = 'subtitle_language';

  final String apiKey;
  final String language; // preferred ISO 639-1 code, e.g. 'en'

  const SubtitleSettings({
    this.apiKey = kDefaultSubtitleApiKey,
    this.language = 'en',
  });

  bool get hasCredentials => apiKey.isNotEmpty;

  static Future<SubtitleSettings> load() async {
    final p = await SharedPreferences.getInstance();
    return SubtitleSettings(
      apiKey: p.getString(_kKey) ?? kDefaultSubtitleApiKey,
      language: p.getString(_kLang) ?? 'en',
    );
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kKey, apiKey);
    await p.setString(_kLang, language);
  }

  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kKey);
  }
}

// ---------------------------------------------------------------------------
// Title normalisation for subtitle lookups.

/// Detects the season/episode numbers carried by a raw playlist episode title
/// like "Breaking Bad S01E05", "The Witcher · S1 E3", "Friends - 01x05" or
/// "House 1 Episode 5". Returns (null, null) when it's a movie / ambiguous.
(int?, int?) parseSeriesRef(String raw) {
  final matcher = RegExp(
          r'(?i)(season\s*(\d{1,2})[^\d]{0,20}?episode\s*(\d{1,2}))'
          r'|(S(\d{1,2})\s*E(\d{1,2}))'
          r'|((?:\b|^)(\d{1,2})\s*[xX×]\s*(\d{1,2})\b)')
      .firstMatch(raw);
  if (matcher == null) return (null, null);
  int? s;
  int? e;
  final g2 = matcher.group(2);
  final g3 = matcher.group(3);
  final g5 = matcher.group(5);
  final g6 = matcher.group(6);
  final g8 = matcher.group(8);
  final g9 = matcher.group(9);
  if (g2 != null && g3 != null) {
    s = int.tryParse(g2);
    e = int.tryParse(g3);
  } else if (g5 != null && g6 != null) {
    s = int.tryParse(g5);
    e = int.tryParse(g6);
  } else if (g8 != null && g9 != null) {
    s = int.tryParse(g8);
    e = int.tryParse(g9);
  }
  if (s == null || e == null || s < 1 || s > 99 || e < 1 || e > 99) {
    return (null, null);
  }
  return (s, e);
}

/// Cleans a raw playlist / Xtream title into the actual show/movie name that
/// SubDL can match, e.g.:
///   "Avengers: Endgame (2019).2160p.4KDL.BluRay.x265" -> "Avengers: Endgame (2019)"
///   "Breaking Bad S01E05 1080p.WEBRip.x264"           -> "Breaking Bad"
///   "The Witcher · S1 E3 Love, Actually"              -> "The Witcher"
String cleanMediaTitle(String raw) {
  var t = raw.trim();
  if (t.isEmpty) return t;
  // Bracketed tags: [1080p], [WEBRip], [S01E01], ...
  t = t.replaceAll(RegExp(r'\[[^\]]*\]'), ' ');
  // Normalise common episode joiners so the season marker below is matched.
  t = t.replaceAll(RegExp(r'\s*[·|]\s*'), ' · ');
  // Drop everything from the season/episode marker onward.
  final marker = RegExp(
      r'(?i)\b(season\s*\d{1,2}[^\d]{0,20}?episode\s*\d{1,2})'
      r'|(S\d{1,2}\s*E\d{1,2})'
      r'|(\d{1,2}\s*[xX×]\s*\d{1,2})');
  final m = marker.firstMatch(t);
  if (m != null && m.start > 0) t = t.substring(0, m.start);
  // Release / quality tokens that never belong to a show name.
  t = t.replaceAll(
      RegExp(
          r'(?i)\b(?:1080p|720p|480p|360p|2160p|1440p|4k|8k|uhd|hdr|hdr10|'
          r'dolby|vision|x264|x265|h264|h265|hevc|avc|av1|webrip|webdl|web-dl|'
          r'bluray|blu-ray|brrip|bdrip|hdrip|hdtv|sdtv|pdtv|satrip|dvdrip|'
          r'dvdscr|hdscr|remux|remastered|remaster|proper|repack|repackage|'
          r'internal|extended|uncut|unrated|theatrical|imax|directors\s*cut|'
          r'multi|dual|synced|forced|muxed|aac|ac3|dts|eac3|truehd|atmos|dd5\.1)\b'),
      ' ');
  // Parenthetical groups except a release year.
  t = t.replaceAll(RegExp(r'\s*\((?!\s*(?:19|20)\d{2}\s*\))[^\)]*\)'), ' ');
  // Stray episode-number residue left on its own ("E5", "S1").
  t = t.replaceAll(RegExp(r'\s*\b[SsEe]\d{1,2}\b'), ' ');
  t = t.replaceAll(RegExp(r'\s*·\s*$|\s*[\.\-_]\s*$'), ' ');
  t = t.replaceAll(RegExp(r'\s{2,}'), ' ');
  return t.trim();
}

/// Free SubDL REST API client (api.subdl.com) — lets the player fetch
/// subtitle tracks for movies and TV episodes by title, in any language.
///
/// No login or username/password: a free API key (embedded by default) is all
/// that's required. Search is by title/type (plus season/episode for TV);
/// download links point at dl.subdl.com.
///
/// Works on Android, iOS, Windows and web: subtitle content is returned as
/// plain text so the caller attaches it with `SubtitleTrack.data(...)` — no
/// file I/O, so there is no platform-specific path handling (and web routes
/// requests through the proxy worker for CORS).
class SubtitleService {
  static const String apiBase = 'https://api.subdl.com/api/v1';
  static const String dlHost = 'https://dl.subdl.com';
  static const String userAgent = 'YBOX TV';

  final String apiKey;

  SubtitleService({required this.apiKey});

  bool get hasCredentials => apiKey.isNotEmpty;

  /// Search for subtitles matching [query]. [type] is 'movie' or 'episode'.
  /// [languages] is a list of ISO 639-1 codes (e.g. ['en','es']) — empty
  /// means "all languages".
  Future<List<SubtitleCandidate>> search(
    String query, {
    String type = 'movie',
    List<String>? languages,
    int? season,
    int? episode,
  }) async {
    if (query.trim().isEmpty) return [];
    final params = <String, String>{
      'api_key': apiKey,
      'film_name': query.trim(),
      'type': type == 'episode' ? 'tv' : 'movie',
      'subs_per_page': '40',
      'unpack': '1',
      if (languages != null && languages.isNotEmpty)
        'languages': languages.map((l) => l.toUpperCase()).join(','),
      if (season != null && season > 0) 'season_number': '$season',
      if (episode != null && episode > 0) 'episode_number': '$episode',
    };
    final qs = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    final res = await _send(
      () => http.get(Uri.parse('${_url('subtitles')}?$qs')),
    );
    final json = _decode(res);
    final subs = json['subtitles'];
    if (subs is! List) return [];
    final out = <SubtitleCandidate>[];
    final seen = <String>{};
    for (final item in subs) {
      if (item is! Map) continue;
      final file = _subtitleFileId(item);
      if (file == null) continue;
      final release = (item['release_name'] as String?) ??
          (item['name'] as String?) ??
          '';
      if (!seen.add(release)) continue;
      out.add(SubtitleCandidate(
        id: file,
        language: _languageCode(item['lang']),
        languageName: (item['lang'] as String?) ?? '',
        fileName: _fileName(item, release),
        title: release,
        downloads: (item['downloads'] as num?)?.toInt() ?? 0,
      ));
    }
    return out;
  }

  /// Download the subtitle identified by [subtitleId] (the download URL/link
  /// recorded by [search]) and return its text (SRT-able). The API can wrap a
  /// subtitle in a zip — it is extracted here, with a plain file accepted too.
  Future<String> download(String subtitleId) async {
    if (subtitleId.isEmpty) {
      throw const SubtitleException('No subtitle download link.');
    }
    final bytes = await _downloadBytes(subtitleId);
    return _extractSubtitle(bytes);
  }

  Future<Uint8List> _downloadBytes(String link) async {
    final res = await _send(
      () => http.get(Uri.parse(WebProxy.relay(link))),
    );
    return res.bodyBytes;
  }

  /// Turn the raw downloaded bytes into subtitle text, expanding a zip if the
  /// API wrapped the subtitle in one (common when a release exposes several
  /// language/HD options).
  String _extractSubtitle(Uint8List bytes) {
    // ZIP magic: PK\x03\x04
    if (bytes.length > 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04) {
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final file in archive) {
        if (file.isFile) {
          final name = file.name.toLowerCase();
          if (name.endsWith('.srt') ||
              name.endsWith('.vtt') ||
              name.endsWith('.ass') ||
              name.endsWith('.ssa')) {
            final text = _decodeText(file.content as List<int>);
            if (text.trim().isNotEmpty) return text;
          }
        }
      }
      throw const SubtitleException('Subtitle zip contained no subtitle file.');
    }
    // Plain UTF-8 / Latin-1 subtitle.
    return _decodeText(bytes);
  }

  String _decodeText(List<int> bytes) {
    // Try UTF-8 (with or without BOM) first; subtitle files are usually UTF-8.
    try {
      final s = utf8.decode(bytes, allowMalformed: false);
      // Reject if it doesn't look like subtitle text at all.
      if (_looksLikeSubtitle(s)) return s;
    } catch (_) {}
    // WebVTT/SRT are text; fall back to Latin-1 (covers the common 8-bit
    // encodings without pulling in a charset dependency).
    final s = latin1.decode(bytes);
    return s;
  }

  bool _looksLikeSubtitle(String s) {
    final t = s.trimLeft();
    return t.startsWith('1') ||
        t.startsWith('WEBVTT') ||
        t.contains('-->') ||
        t.contains('\n1\n');
  }

  /// Best stable ID for a subtitle: prefer an explicit download URL/link, then
  /// the OSDb-relative url (resolved to a full dl.subdl.com URL).
  String? _subtitleFileId(Map item) {
    final link = (item['download_link'] as String?)?.trim();
    if (link != null && link.isNotEmpty) return link;
    final url = (item['url'] as String?)?.trim();
    if (url != null && url.isNotEmpty) {
      return url.startsWith('http') ? url : '$dlHost$url';
    }
    return null;
  }

  String _fileName(Map item, String release) {
    final name = (item['name'] as String?)?.trim() ?? '';
    final base = name.isNotEmpty ? name : release;
    return base;
  }

  /// SubDL reports languages as names like "english"; map the common ones to
  /// ISO 639-1 for display/attachment, defaulting to the raw token.
  static const Map<String, String> _langCodeMap = {
    'english': 'en',
    'spanish': 'es',
    'french': 'fr',
    'german': 'de',
    'portuguese': 'pt',
    'italian': 'it',
    'russian': 'ru',
    'arabic': 'ar',
    'turkish': 'tr',
    'hindi': 'hi',
    'chinese': 'zh',
    'japanese': 'ja',
    'korean': 'ko',
    'dutch': 'nl',
    'polish': 'pl',
    'greek': 'el',
    'hebrew': 'he',
    'swedish': 'sv',
  };

  String _languageCode(Object? lang) {
    final raw = (lang as String?)?.toLowerCase() ?? '';
    return _langCodeMap[raw] ?? raw;
  }

  Future<http.Response> _send(Future<http.Response> Function() run,
      {int attempts = 2}) async {
    http.Response? last;
    for (var i = 0; i < attempts; i++) {
      try {
        last = await run().timeout(const Duration(seconds: 25));
        break;
      } catch (_) {
        // Retry transient network errors once.
      }
    }
    if (last == null) {
      throw const SubtitleException(
          'Could not reach the subtitle service. Check your connection.');
    }
    if (last.statusCode >= 200 && last.statusCode < 300) return last;
    throw SubtitleException('Subtitle service error (HTTP ${last.statusCode}).');
  }

  Map<String, dynamic> _decode(http.Response res) {
    try {
      final j = jsonDecode(utf8.decode(res.bodyBytes));
      return j is Map<String, dynamic> ? j : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  String _url(String path) => WebProxy.relay('$apiBase/$path');
}

class SubtitleException implements Exception {
  final String message;
  const SubtitleException(this.message);

  @override
  String toString() => message;
}

/// A candidate subtitle file the user can pick, in a chosen language.
class SubtitleCandidate {
  final String id; // download URL/link
  final String language; // ISO 639-1 code, e.g. 'en'
  final String? languageName;
  final String fileName;
  final String? title; // release name when known
  final int downloads;

  const SubtitleCandidate({
    required this.id,
    required this.language,
    this.languageName,
    required this.fileName,
    this.title,
    this.downloads = 0,
  });
}
