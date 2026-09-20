/// Data models mirroring the Firestore documents (SPEC.md section 6.2).
library;

/// Subscription durations (SPEC 5.1): key → milliseconds.
/// Months are 30 days, years are 365 days.
class SubDurations {
  static const Map<String, int> all = {
    '1w': 7 * _day,
    '2w': 14 * _day,
    '1m': 30 * _day,
    '3m': 90 * _day,
    '6m': 180 * _day,
    '1y': 365 * _day,
    '2y': 2 * 365 * _day,
  };

  static const Map<String, String> labels = {
    '1w': '1 week',
    '2w': '2 weeks',
    '1m': '1 month',
    '3m': '3 months',
    '6m': '6 months',
    '1y': '1 year',
    '2y': '2 years',
  };

  static const int _day = 24 * 60 * 60 * 1000;

  /// Units for admin-entered custom durations: unit → milliseconds.
  static const Map<String, int> unitMs = {
    'hours': 60 * 60 * 1000,
    'days': _day,
    'weeks': 7 * _day,
    'months': 30 * _day,
    'years': 365 * _day,
  };

  /// "9 Aug 2026, 14:05" — expiry timestamps in confirmations.
  static String dateLabel(int epochMs) {
    final d = DateTime.fromMillisecondsSinceEpoch(epochMs);
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]} ${d.year}, $hh:$mm';
  }

  /// "23d left" / "5h left" / "Expired" / "No subscription".
  static String remainingLabel(int expiry) {
    if (expiry <= 0) return 'No subscription';
    final left = expiry - DateTime.now().millisecondsSinceEpoch;
    if (left <= 0) return 'Expired';
    final days = left ~/ _day;
    if (days >= 1) return '${days}d left';
    final hours = left ~/ (60 * 60 * 1000);
    if (hours >= 1) return '${hours}h left';
    return '${left ~/ 60000}m left';
  }
}

int _asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : 0);
String _asString(Object? v) => v is String ? v : '';
bool _asBool(Object? v, [bool fallback = false]) =>
    v is bool ? v : fallback;

/// devices/{deviceId} — presence doc upserted by each player.
class Device {
  final String deviceId;
  final String name;
  final String platform;
  final String model;
  final String appVersion;
  final String publicIp;
  final String localIp;
  final String username; // logged-in player account, may be empty
  final String uid;
  final int lastSeen; // epoch ms
  final String watching;

  const Device({
    required this.deviceId,
    required this.name,
    required this.platform,
    required this.model,
    required this.appVersion,
    required this.publicIp,
    required this.localIp,
    required this.username,
    required this.uid,
    required this.lastSeen,
    required this.watching,
  });

  bool get online =>
      DateTime.now().millisecondsSinceEpoch - lastSeen < 2 * 60 * 1000;

  String get lastSeenLabel {
    if (lastSeen == 0) return 'never';
    final diff = DateTime.now().millisecondsSinceEpoch - lastSeen;
    final mins = diff ~/ 60000;
    if (mins < 1) return 'just now';
    if (mins < 60) return '${mins}m ago';
    final hours = mins ~/ 60;
    if (hours < 24) return '${hours}h ago';
    return '${hours ~/ 24}d ago';
  }

  factory Device.fromDoc(String id, Map<String, Object?> m) => Device(
        deviceId: id,
        name: _asString(m['name']).isEmpty ? 'Unknown device' : _asString(m['name']),
        platform: _asString(m['platform']),
        model: _asString(m['model']),
        appVersion: _asString(m['appVersion']),
        publicIp: _asString(m['publicIp']),
        localIp: _asString(m['localIp']),
        username: _asString(m['username']),
        uid: _asString(m['uid']),
        lastSeen: _asInt(m['lastSeen']),
        watching: _asString(m['watching']),
      );
}

/// playlists/{playlistId} — config entries applied live by players.
class PlaylistEntry {
  final String id;
  final String kind; // 'xtream' | 'm3u' | 'm3ufile'
  final String name;
  final String server;
  final String username;
  final String password;
  final String url;
  final String content; // inline m3u body for kind 'm3ufile'
  final bool replaceBuiltin;

  /// 'all', or a List<String> of usernames.
  final Object targets;
  final int expiresAt; // epoch ms, 0 = never
  final int updatedAt;
  final bool active;

  const PlaylistEntry({
    required this.id,
    required this.kind,
    required this.name,
    this.server = '',
    this.username = '',
    this.password = '',
    this.url = '',
    this.content = '',
    this.replaceBuiltin = false,
    this.targets = 'all',
    this.expiresAt = 0,
    this.updatedAt = 0,
    this.active = true,
  });

  bool get isBuiltin => id == 'builtin';
  bool get targetsAll => targets is String && targets == 'all';
  List<String> get targetUsernames =>
      targets is List ? (targets as List).whereType<String>().toList() : const [];

  bool get expired =>
      expiresAt > 0 && DateTime.now().millisecondsSinceEpoch >= expiresAt;

  String get expiryLabel {
    if (expiresAt <= 0) return '';
    if (expired) return 'expired';
    return 'expires in ${SubDurations.remainingLabel(expiresAt).replaceAll(' left', '')}';
  }

  String get targetsLabel => targetsAll
      ? 'Target: all users'
      : 'Target: ${targetUsernames.length} user(s)';

  factory PlaylistEntry.fromDoc(String id, Map<String, Object?> m) =>
      PlaylistEntry(
        id: id,
        kind: _asString(m['kind']).isEmpty ? 'xtream' : _asString(m['kind']),
        name: _asString(m['name']),
        server: _asString(m['server']),
        username: _asString(m['username']),
        password: _asString(m['password']),
        url: _asString(m['url']),
        content: _asString(m['content']),
        replaceBuiltin: _asBool(m['replaceBuiltin']),
        targets: m['targets'] is List ? m['targets']! : _asString(m['targets']).isEmpty ? 'all' : m['targets']!,
        expiresAt: _asInt(m['expiresAt']),
        updatedAt: _asInt(m['updatedAt']),
        active: _asBool(m['active'], true),
      );

  Map<String, Object?> toDoc() => {
        'kind': kind,
        'name': name,
        'server': server,
        'username': username,
        'password': password,
        'url': url,
        'content': content,
        'replaceBuiltin': replaceBuiltin,
        'targets': targets,
        'expiresAt': expiresAt,
        'updatedAt': updatedAt,
        'active': active,
      };
}

/// users/{uid} — account profile.
class YUser {
  final String uid;
  final String username;
  final String name;
  final String phone;
  final String email;
  final String role; // 'user' | 'admin'
  final String origin; // 'self' | 'admin'
  final bool active;
  final int subExpiry; // epoch ms, 0 = none
  final int createdAt;
  final String createdBy;

  const YUser({
    required this.uid,
    required this.username,
    this.name = '',
    this.phone = '',
    this.email = '',
    this.role = 'user',
    this.origin = 'admin',
    this.active = true,
    this.subExpiry = 0,
    this.createdAt = 0,
    this.createdBy = '',
  });

  bool get isAdmin => role == 'admin';
  bool get selfRegistered => origin == 'self';
  bool get subscriptionActive =>
      subExpiry > DateTime.now().millisecondsSinceEpoch;

  String get subscriptionLabel => SubDurations.remainingLabel(subExpiry);

  factory YUser.fromDoc(String uid, Map<String, Object?> m) => YUser(
        uid: uid,
        username: _asString(m['username']),
        name: _asString(m['name']),
        phone: _asString(m['phone']),
        email: _asString(m['email']),
        role: _asString(m['role']).isEmpty ? 'user' : _asString(m['role']),
        origin: _asString(m['origin']).isEmpty ? 'admin' : _asString(m['origin']),
        active: _asBool(m['active'], true),
        subExpiry: _asInt(m['subExpiry']),
        createdAt: _asInt(m['createdAt']),
        createdBy: _asString(m['createdBy']),
      );
}

/// chats/{uid}/messages/{autoId}
class ChatMessage {
  final String id;
  final String username; // filled from the thread context
  final bool fromAdmin;
  final String text;
  final int ts;

  const ChatMessage({
    required this.id,
    required this.username,
    required this.fromAdmin,
    required this.text,
    required this.ts,
  });

  String get timeLabel {
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.day}/${dt.month}';
  }

  factory ChatMessage.fromDoc(
    String id,
    Map<String, Object?> m, {
    String username = '',
  }) =>
      ChatMessage(
        id: id,
        username: username,
        fromAdmin: _asBool(m['fromAdmin']),
        text: _asString(m['text']),
        ts: _asInt(m['ts']),
      );
}

/// chats/{uid} — one row in the admin Chat tab conversation list.
class Conversation {
  final String uid;
  final String username;
  final String lastMessage;
  final bool lastFromAdmin;
  final int lastTs;
  final int unreadByAdmin;

  const Conversation({
    required this.uid,
    required this.username,
    required this.lastMessage,
    required this.lastFromAdmin,
    required this.lastTs,
    required this.unreadByAdmin,
  });

  String get timeLabel =>
      ChatMessage(id: '', username: '', fromAdmin: false, text: '', ts: lastTs)
          .timeLabel;

  factory Conversation.fromDoc(String uid, Map<String, Object?> m) =>
      Conversation(
        uid: uid,
        username: _asString(m['username']),
        lastMessage: _asString(m['lastMessage']),
        lastFromAdmin: _asBool(m['lastFromAdmin']),
        lastTs: _asInt(m['lastTs']),
        unreadByAdmin: _asInt(m['unreadByAdmin']),
      );
}
