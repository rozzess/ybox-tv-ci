import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';

/// v3: user <-> admin chat over Firestore (realtime, works anywhere).
///
/// Thread doc `chats/{uid}` carries unread counters + the user's
/// `clearedBefore` marker; messages live in `chats/{uid}/messages`.
class ChatService {
  final _db = FirebaseFirestore.instance;

  final List<ChatMessage> messages = [];
  int unread = 0;

  int _clearedBefore = 0;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _msgSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _threadSub;
  String? _uid;
  String _username = '';

  /// Fired on any change (new messages, unread counter).
  void Function()? onChanged;

  bool get attached => _uid != null;

  /// Starts realtime listeners for the signed-in user. Safe to call again.
  void attach({required String uid, required String username}) {
    if (_uid == uid) {
      _username = username;
      return;
    }
    detach();
    _uid = uid;
    _username = username;

    _threadSub = _db.collection('chats').doc(uid).snapshots().listen(
      (snap) {
        final d = snap.data();
        final cleared = (d?['clearedBefore'] as num?)?.toInt() ?? 0;
        final unreadByUser = (d?['unreadByUser'] as num?)?.toInt() ?? 0;
        var changed = unread != unreadByUser;
        unread = unreadByUser;
        if (cleared != _clearedBefore) {
          _clearedBefore = cleared;
          final before = messages.length;
          messages.removeWhere((m) => m.ts <= cleared);
          changed = changed || messages.length != before;
        }
        if (changed) onChanged?.call();
      },
      onError: (_) {},
    );

    _msgSub = _db
        .collection('chats')
        .doc(uid)
        .collection('messages')
        .orderBy('ts')
        .snapshots()
        .listen(
      (snap) {
        messages
          ..clear()
          ..addAll(snap.docs
              .map((d) => ChatMessage.fromMap(d.id, d.data()))
              .where((m) => m.ts > _clearedBefore));
        onChanged?.call();
      },
      onError: (_) {},
    );
  }

  void detach() {
    _msgSub?.cancel();
    _threadSub?.cancel();
    _msgSub = null;
    _threadSub = null;
    _uid = null;
    messages.clear();
    unread = 0;
    _clearedBefore = 0;
  }

  /// Marks the thread as read by this user.
  Future<void> markAllRead() async {
    unread = 0;
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db
          .collection('chats')
          .doc(uid)
          .set({'unreadByUser': 0}, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Returns true when sent.
  Future<bool> send(String text) async {
    final uid = _uid;
    if (uid == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      final thread = _db.collection('chats').doc(uid);
      await thread.collection('messages').add({
        'fromAdmin': false,
        'text': text,
        'ts': now,
      }).timeout(const Duration(seconds: 10));
      await thread.set({
        'username': _username,
        'lastMessage': text,
        'lastTs': now,
        'unreadByAdmin': FieldValue.increment(1),
      }, SetOptions(merge: true));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Clears the conversation on the user's side (admin keeps history).
  Future<bool> clear() async {
    final uid = _uid;
    if (uid == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      await _db.collection('chats').doc(uid).set({
        'clearedBefore': now,
        'unreadByUser': 0,
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 10));
      _clearedBefore = now;
      messages.clear();
      unread = 0;
      onChanged?.call();
      return true;
    } catch (_) {
      return false;
    }
  }
}
