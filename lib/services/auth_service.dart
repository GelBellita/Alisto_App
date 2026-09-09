import 'package:firebase_auth/firebase_auth.dart';

import 'firestore_service.dart';

/// Wraps Firebase Auth for the app.
///
/// Sign-up now collects a REAL email address, so that email is used as the
/// Firebase Auth identity directly. (The old build faked an email from the
/// phone number — "09171234567@alisto.local" — because the form had no email
/// field. That workaround is gone: the phone number is now stored as profile
/// data only, and password reset emails actually work.)
class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Stream<User?> get authStateChanges => _auth.authStateChanges();
  static User? get currentUser => _auth.currentUser;

  /// Creates a new account and a matching Firestore user profile.
  /// Returns null on success, or an error message on failure.
  static Future<String?> signUp({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await credential.user!.updateDisplayName(fullName.trim());
      await FirestoreService.createUserProfile(
        uid: credential.user!.uid,
        fullName: fullName.trim(),
        email: email.trim(),
        phone: phone.trim(),
      );
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'An account with this email already exists.';
        case 'weak-password':
          return 'Password should be at least 6 characters.';
        case 'invalid-email':
          return 'That email address looks invalid.';
        case 'network-request-failed':
          return 'No internet connection. Please try again.';
        default:
          return e.message ?? 'Sign up failed. Please try again.';
      }
    }
  }

  /// Returns null on success, or an error message on failure.
  static Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
        case 'invalid-credential':
          return 'No account found with that email and password.';
        case 'wrong-password':
          return 'Incorrect password.';
        case 'invalid-email':
          return 'That email address looks invalid.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'network-request-failed':
          return 'No internet connection. Please try again.';
        default:
          return e.message ?? 'Login failed. Please try again.';
      }
    }
  }

  /// Sends a password reset link. Now possible because the account email is
  /// a real address. Wire this to a "Forgot password?" link when you need it.
  static Future<String?> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Could not send the reset email.';
    }
  }

  static Future<void> logout() => _auth.signOut();
}
