import 'package:flutter/foundation.dart';

/// HTTPS relay for HTTP-only IPTV panels.
///
/// Browsers refuse to fetch `http://` resources from an `https://` website
/// (mixed content), so on web the app routes panel traffic through a
/// Cloudflare Worker that re-hosts it over HTTPS. Configured at build time
/// with `--dart-define=YBOX_WEB_PROXY=https://<worker>.workers.dev`; empty on
/// every other platform. Even on web, https panels bypass it entirely.
class WebProxy {
  static const String base = String.fromEnvironment('YBOX_WEB_PROXY');

  /// Rewrites [url] to the proxy form `base/<scheme>/<host[:port]>/<path>`,
  /// keeping the query string and the file extension (media_kit's web player
  /// decides HLS vs direct playback from the URL). Non-http URLs pass through
  /// untouched.
  static String apply(String url) {
    if (!kIsWeb || base.isEmpty || !url.startsWith('http://')) return url;
    return relay(url);
  }

  /// Encapsulate any http(s) URL as `base/<scheme>/<host[:port]>/<path>?<query>`
  /// so the worker re-hosts it over HTTPS with CORS. Only meaningful on web
  /// ([base] is empty elsewhere and https calls don't need a relay) — used to
  /// fetch external resources such as subtitles from a browser without
  /// tripping mixed-content or CORS.
  static String relay(String url) {
    if (!kIsWeb || base.isEmpty) return url;
    final u = Uri.tryParse(url);
    if (u == null || (u.scheme != 'http' && u.scheme != 'https')) return url;
    final host = u.hasPort ? '${u.host}:${u.port}' : u.host;
    return '$base/${u.scheme}/$host${u.path}${u.hasQuery ? '?${u.query}' : ''}';
  }
}
