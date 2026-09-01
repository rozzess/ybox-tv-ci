import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// v3: Firebase-backed sessions. Usernames map to synthetic auth emails
/// (`<username>@users.ybox.tv`); the real profile (name, phone, email, role,
/// subscription) lives in `users/{uid}` and is watched live.
class AuthService {
  static const emailDomain = 'users.ybox.tv';
  static final usernameRx = RegExp(r'^[a-z0-9_.-]{3,24}$');

  // Profile cache so needsLogin/subExpiry work instantly and offline.
  static const _kUser = 'ybox.auth.user';
  static const _kName = 'ybox.auth.name';
  static const _kRole = 'ybox.auth.role';
  static const _kSubExpiry = 'ybox.auth.subExpiry';
  static const _kActive = 'ybox.auth.active';

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  String? username;
  String? name;
  String role = 'user';
  int subExpiry = 0; // epoch ms, 0 = none
  bool active = true;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;

  /// Fired whenever the live profile changes (role/subscription updates).
  void Function()? onProfileChanged;

  String? get uid => _auth.currentUser?.uid;
  bool get hasSession => _auth.currentUser != null;
  bool get isAdmin => role == 'admin';

  /// Remaining subscription time. Zero/negative = expired (subExpiry == 0
  /// also counts as no subscription).
  Duration get subscriptionRemaining {
    if (subExpiry <= 0) return Duration.zero;
    return Duration(
        milliseconds: subExpiry - DateTime.now().millisecondsSinceEpoch);
  }

  bool get subscriptionExpired =>
      !active || subscriptionRemaining <= Duration.zero;

  static String emailFor(String username) =>
      '${username.trim().toLowerCase()}@$emailDomain';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    username = prefs.getString(_kUser);
    name = prefs.getString(_kName);
    role = prefs.getString(_kRole) ?? 'user';
    subExpiry = prefs.getInt(_kSubExpiry) ?? 0;
    active = prefs.getBool(_kActive) ?? true;
    if (hasSession) _watchProfile();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUser, username ?? '');
    await prefs.setString(_kName, name ?? '');
    await prefs.setString(_kRole, role);
    await prefs.setInt(_kSubExpiry, subExpiry);
    await prefs.setBool(_kActive, active);
  }

  void _applyProfile(Map<String, dynamic> data) {
    username = data['username']?.toString() ?? username;
    name = data['name']?.toString() ?? name;
    role = data['role']?.toString() == 'admin' ? 'admin' : 'user';
    subExpiry = (data['subExpiry'] as num?)?.toInt() ?? 0;
    active = data['active'] != false;
    unawaited(_persist());
  }

  /// Live profile updates: subscription grants, role changes, deactivation.
  void _watchProfile() {
    _profileSub?.cancel();
    final id = uid;
    if (id == null) return;
    _profileSub = _db.collection('users').doc(id).snapshots().listen(
      (snap) {
        final data = snap.data();
        if (data == null) return;
        _applyProfile(data);
        onProfileChanged?.call();
      },
      onError: (_) {}, // offline / rules hiccups: keep cached profile
    );
  }

  /// Force-refresh the profile from the server. Returns true when reached.
  Future<bool> refreshProfile() async {
    final id = uid;
    if (id == null) return false;
    try {
      final snap = await _db
          .collection('users')
          .doc(id)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));
      final data = snap.data();
      if (data == null) return false;
      _applyProfile(data);
      onProfileChanged?.call();
      return true;
    } catch (_) {
      return false;
    }
  }

  String? _validUsername(String user) {
    final u = user.trim().toLowerCase();
    if (!usernameRx.hasMatch(u)) {
      return 'Username must be 3-24 characters: letters, numbers, . _ -';
    }
    return null;
  }

  static String friendlyAuthError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          return 'Wrong username or password';
        case 'email-already-in-use':
          return 'That username is already taken';
        case 'weak-password':
          return 'Password is too weak — use at least 6 characters';
        case 'too-many-requests':
          return 'Too many attempts — wait a moment and try again';
        case 'network-request-failed':
          return 'Check your internet connection';
        case 'user-disabled':
          return 'This account has been disabled';
      }
      return 'Sign-in failed (${e.code})';
    }
    return 'Check your internet connection';
  }

  /// Returns null on success, or a friendly error message.
  Future<String?> login(String user, String password) async {
    final invalid = _validUsername(user);
    if (invalid != null) return invalid;
    try {
      await _auth.signInWithEmailAndPassword(
          email: emailFor(user), password: password);
    } catch (e) {
      return friendlyAuthError(e);
    }
    // Load the profile; a missing profile means a broken account.
    try {
      final snap = await _db.collection('users').doc(uid).get();
      final data = snap.data();
      if (data == null) {
        await logout();
        return 'Account profile not found — contact your admin';
      }
      _applyProfile(data);
      if (!active) {
        await logout();
        return 'Your account is disabled. Contact your admin.';
      }
    } catch (_) {
      // Offline profile fetch: Firestore cache may still have served it; if
      // not, fall back to cached prefs. The session itself is valid.
    }
    _watchProfile();
    return null;
  }

  /// Creates a self-registered account and signs it in. Null on success.
  Future<String?> register({
    required String user,
    required String password,
    required String fullName,
    required String phone,
    required String email,
  }) async {
    final invalid = _validUsername(user);
    if (invalid != null) return invalid;
    final uname = user.trim().toLowerCase();
    try {
      final taken = await _db.collection('usernames').doc(uname).get();
      if (taken.exists) return 'That username is already taken';
    } catch (_) {
      return 'Check your internet connection';
    }
    try {
      await _auth.createUserWithEmailAndPassword(
          email: emailFor(uname), password: password);
    } catch (e) {
      return friendlyAuthError(e);
    }
    final id = uid;
    if (id == null) return 'Registration failed — try again';
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db.collection('users').doc(id).set({
        'username': uname,
        'name': fullName,
        'phone': phone,
        'email': email,
        'role': 'user',
        'origin': 'self',
        'active': true,
        'subExpiry': 0,
        'createdAt': now,
        'createdBy': 'self',
      });
      await _db.collection('usernames').doc(uname).set({'uid': id});
    } catch (_) {
      return 'Could not create your profile — check your connection';
    }
    username = uname;
    name = fullName;
    role = 'user';
    subExpiry = 0;
    active = true;
    await _persist();
    _watchProfile();
    return null;
  }

  Future<void> logout() async {
    await _profileSub?.cancel();
    _profileSub = null;
    try {
      await _auth.signOut();
    } catch (_) {}
    username = null;
    name = null;
    role = 'user';
    subExpiry = 0;
    active = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUser);
    await prefs.remove(_kName);
    await prefs.remove(_kRole);
    await prefs.remove(_kSubExpiry);
    await prefs.remove(_kActive);
  }

  void dispose() {
    _profileSub?.cancel();
  }
}
