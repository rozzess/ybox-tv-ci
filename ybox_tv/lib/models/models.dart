import 'dart:convert';

/// Content sections of the app.
enum ContentType { live, movie, series }

extension ContentTypeX on ContentType {
  String get key => switch (this) {
        ContentType.live => 'live',
        ContentType.movie => 'movie',
        ContentType.series => 'series',
      };

  String get label => switch (this) {
        ContentType.live => 'Live TV',
        ContentType.movie => 'Movies',
        ContentType.series => 'Series',
      };

  String get itemLabel => switch (this) {
        ContentType.live => 'Channels',
        ContentType.movie => 'Movies',
        ContentType.series => 'Series',
      };

  static ContentType fromKey(String k) => switch (k) {
        'movie' => ContentType.movie,
        'series' => ContentType.series,
        _ => ContentType.live,
      };
}

/// A playable (or browsable, for series) content item.
class Channel {
  final String id;
  final String name;
  final String? logoUrl;
  final String group;
  final String streamUrl; // empty for Xtream series (open series detail instead)
  final ContentType type;

  const Channel({
    required this.id,
    required this.name,
    this.logoUrl,
    required this.group,
    required this.streamUrl,
    required this.type,
  });

  bool get isPlayable => streamUrl.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'logoUrl': logoUrl,
        'group': group,
        'streamUrl': streamUrl,
        'type': type.key,
      };

  factory Channel.fromJson(Map<String, dynamic> j) => Channel(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        logoUrl: j['logoUrl']?.toString(),
        group: j['group']?.toString() ?? 'Other',
        streamUrl: j['streamUrl']?.toString() ?? '',
        type: ContentTypeX.fromKey(j['type']?.toString() ?? 'live'),
      );
}

/// A category / group of channels.
class Group {
  final String name;
  final ContentType type;
  final int count;

  const Group({required this.name, required this.type, required this.count});
}

class Episode {
  final String id;
  final String title;
  final String streamUrl;
  final int season;
  final int episodeNum;
  final String? info;

  const Episode({
    required this.id,
    required this.title,
    required this.streamUrl,
    required this.season,
    required this.episodeNum,
    this.info,
  });
}

class Season {
  final int season;
  final List<Episode> episodes;

  const Season({required this.season, required this.episodes});
}

class SeriesInfo {
  final String id;
  final String name;
  final String? cover;
  final String? plot;
  final List<Season> seasons;

  const SeriesInfo({
    required this.id,
    required this.name,
    this.cover,
    this.plot,
    required this.seasons,
  });
}

enum PlaylistKind { xtream, m3uUrl, m3uFile }

extension PlaylistKindX on PlaylistKind {
  String get key => switch (this) {
        PlaylistKind.xtream => 'xtream',
        PlaylistKind.m3uUrl => 'm3uUrl',
        PlaylistKind.m3uFile => 'm3uFile',
      };

  String get label => switch (this) {
        PlaylistKind.xtream => 'Xtream Codes',
        PlaylistKind.m3uUrl => 'M3U URL',
        PlaylistKind.m3uFile => 'M3U File',
      };

  static PlaylistKind fromKey(String k) => switch (k) {
        'm3uUrl' => PlaylistKind.m3uUrl,
        'm3uFile' => PlaylistKind.m3uFile,
        _ => PlaylistKind.xtream,
      };
}

class Playlist {
  final String id;
  final String name;
  final PlaylistKind kind;
  final String? server; // xtream
  final String? username; // xtream
  final String? password; // xtream
  final String? url; // m3u url or local file path
  final String? content; // inline m3u body (admin "M3U file" push)
  final int expiresAt; // epoch ms, 0 = never (set by admin pushes)

  const Playlist({
    required this.id,
    required this.name,
    required this.kind,
    this.server,
    this.username,
    this.password,
    this.url,
    this.content,
    this.expiresAt = 0,
  });

  static const builtinId = 'builtin';
  bool get isBuiltin => id == builtinId;

  bool get isExpired =>
      expiresAt > 0 && DateTime.now().millisecondsSinceEpoch >= expiresAt;

  Playlist copyWith({
    String? name,
    String? server,
    String? username,
    String? password,
    String? url,
    String? content,
    int? expiresAt,
  }) =>
      Playlist(
        id: id,
        name: name ?? this.name,
        kind: kind,
        server: server ?? this.server,
        username: username ?? this.username,
        password: password ?? this.password,
        url: url ?? this.url,
        content: content ?? this.content,
        expiresAt: expiresAt ?? this.expiresAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.key,
        'server': server,
        'username': username,
        'password': password,
        'url': url,
        if (content != null && content!.isNotEmpty) 'content': content,
        'expiresAt': expiresAt,
      };

  factory Playlist.fromJson(Map<String, dynamic> j) => Playlist(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? 'Playlist',
        kind: PlaylistKindX.fromKey(j['kind']?.toString() ?? 'xtream'),
        server: j['server']?.toString(),
        username: j['username']?.toString(),
        password: j['password']?.toString(),
        url: j['url']?.toString(),
        content: j['content']?.toString(),
        expiresAt: int.tryParse(j['expiresAt']?.toString() ?? '') ?? 0,
      );

  static String encodeList(List<Playlist> list) =>
      jsonEncode(list.map((p) => p.toJson()).toList());

  static List<Playlist> decodeList(String s) {
    try {
      final raw = jsonDecode(s) as List;
      return raw
          .map((e) => Playlist.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}

/// One playlist document pushed by the admin (Firestore `playlists/{docId}`).
/// Declarative: the full set of docs visible to this user IS the admin state.
class AdminPlaylistDoc {
  final String docId;
  final PlaylistKind kind;
  final String name;
  final String? server;
  final String? username;
  final String? password;
  final String? url;
  final String? content; // inline m3u body for kind 'm3ufile'
  final bool replaceBuiltin;
  final int expiresAt; // epoch ms, 0 = never
  final bool active;

  const AdminPlaylistDoc({
    required this.docId,
    required this.kind,
    required this.name,
    this.server,
    this.username,
    this.password,
    this.url,
    this.content,
    this.replaceBuiltin = false,
    this.expiresAt = 0,
    this.active = true,
  });

  /// Whether this playlist targets [username]. `targets` is 'all' or a list
  /// of usernames.
  static bool targetsUser(dynamic targets, String username) {
    if (targets == null) return true;
    if (targets is String) {
      return targets.trim().isEmpty || targets == 'all';
    }
    if (targets is List) {
      return targets.map((e) => e.toString()).contains(username);
    }
    return false;
  }

  factory AdminPlaylistDoc.fromMap(String docId, Map<String, dynamic> d) =>
      AdminPlaylistDoc(
        docId: docId,
        kind: switch (d['kind']?.toString()) {
          'm3u' || 'm3uUrl' => PlaylistKind.m3uUrl,
          'm3ufile' || 'm3uFile' => PlaylistKind.m3uFile,
          _ => PlaylistKind.xtream,
        },
        name: d['name']?.toString() ?? 'Playlist',
        server: d['server']?.toString(),
        username: d['username']?.toString(),
        password: d['password']?.toString(),
        url: d['url']?.toString(),
        content: d['content']?.toString(),
        replaceBuiltin: d['replaceBuiltin'] == true,
        expiresAt: (d['expiresAt'] as num?)?.toInt() ?? 0,
        active: d['active'] != false,
      );
}

/// One chat message between this user and the admin.
class ChatMessage {
  final String id; // Firestore doc id
  final bool fromAdmin;
  final String text;
  final int ts; // epoch ms

  const ChatMessage({
    required this.id,
    required this.fromAdmin,
    required this.text,
    required this.ts,
  });

  factory ChatMessage.fromMap(String id, Map<String, dynamic> d) =>
      ChatMessage(
        id: id,
        fromAdmin: d['fromAdmin'] == true,
        text: d['text']?.toString() ?? '',
        ts: (d['ts'] as num?)?.toInt() ?? 0,
      );
}

/// "Continue watching" entry.
class RecentEntry {
  final Channel channel;
  final int positionMs;
  final int updatedAt; // epoch ms

  const RecentEntry({
    required this.channel,
    required this.positionMs,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'channel': channel.toJson(),
        'positionMs': positionMs,
        'updatedAt': updatedAt,
      };

  factory RecentEntry.fromJson(Map<String, dynamic> j) => RecentEntry(
        channel: Channel.fromJson((j['channel'] as Map).cast<String, dynamic>()),
        positionMs: int.tryParse(j['positionMs']?.toString() ?? '') ?? 0,
        updatedAt: int.tryParse(j['updatedAt']?.toString() ?? '') ?? 0,
      );
}
