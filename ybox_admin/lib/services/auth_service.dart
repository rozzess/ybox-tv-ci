import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/models.dart';

/// Admin sign-in (SPEC 6.1): usernames map to synthetic auth emails
/// `<username>@users.ybox.tv`; the real profile lives in users/{uid}.
/// Only accounts whose profile role == 'admin' may use this app.
class AdminAuth {
  static final RegExp usernamePattern = RegExp(r'^[a-z0-9_.\-]{3,24}$');

  static String emailFor(String username) =>
      '${username.trim().toLowerCase()}@users.ybox.tv';

  static User? get currentUser => FirebaseAuth.instance.currentUser;

  /// Signs in and verifies the admin role. Returns the profile on success;
  /// throws a [String] with a friendly message otherwise.
  static Future<YUser> signIn(String username, String password) async {
    final uname = username.trim().toLowerCase();
    if (!usernamePattern.hasMatch(uname)) {
      throw 'Enter a valid username (3–24 letters, digits, . _ -)';
    }
    if (password.isEmpty) throw 'Enter your password';

    final UserCredential cred;
    try {
      cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailFor(uname),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw friendlyAuthError(e);
    }

    final profile = await loadProfile(cred.user!.uid);
    if (profile == null) {
      await FirebaseAuth.instance.signOut();
      throw 'Account has no profile — contact support';
    }
    if (!profile.isAdmin) {
      await FirebaseAuth.instance.signOut();
      throw 'This account is not an admin';
    }
    return profile;
  }

  static Future<YUser?> loadProfile(String uid) async {
    final snap =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = snap.data();
    if (data == null) return null;
    return YUser.fromDoc(uid, data);
  }

  /// Change the signed-in admin's own password (re-authenticates first).
  static Future<void> changeOwnPassword(
      String currentPassword, String newPassword) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) throw 'Not signed in';
    if (newPassword.length < 6) throw 'New password must be 6+ characters';
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(
          email: user.email!,
          password: currentPassword,
        ),
      );
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw friendlyAuthError(e);
    }
  }

  static Future<void> signOut() => FirebaseAuth.instance.signOut();

  static String friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Wrong username or password';
      case 'email-already-in-use':
        return 'Username already taken';
      case 'weak-password':
        return 'Password too weak — use 6+ characters';
      case 'network-request-failed':
        return 'Check your internet connection';
      case 'too-many-requests':
        return 'Too many attempts — try again in a minute';
      case 'user-disabled':
        return 'This account is disabled';
      case 'requires-recent-login':
        return 'Current password incorrect';
      default:
        return 'Sign-in failed (${e.code})';
    }
  }
}
