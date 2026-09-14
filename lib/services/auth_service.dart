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
  /// a real address. Wired to the "Forgot password?" link on the login
  /// screen (see ForgotPasswordScreen in auth_screens.dart).
  static Future<String?> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          // Deliberately vague — confirming/denying an account exists for
          // a given email is an account-enumeration risk. Firebase itself
          // no longer throws this for reset emails on most projects, but
          // handle it just in case.
          return 'If an account exists for that email, a reset link has been sent.';
        case 'invalid-email':
          return 'That email address looks invalid.';
        case 'network-request-failed':
          return 'No internet connection. Please try again.';
        default:
          return e.message ?? 'Could not send the reset email.';
      }
    }
  }

  /// Re-authenticates the current user with their existing password —
  /// Firebase requires a "fresh" sign-in before sensitive account changes
  /// like updating the password or email address.
  static Future<String?> _reauthenticate(String currentPassword) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      return 'No logged-in user found.';
    }
    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          return 'Your current password is incorrect.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        case 'network-request-failed':
          return 'No internet connection. Please try again.';
        default:
          return e.message ?? 'Could not verify your current password.';
      }
    }
  }

  /// Changes the account password. Requires the current password to
  /// re-authenticate first. Returns null on success, or an error message
  /// on failure.
  static Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final reauthError = await _reauthenticate(currentPassword);
    if (reauthError != null) return reauthError;

    try {
      await _auth.currentUser!.updatePassword(newPassword);
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'weak-password':
          return 'Password should be at least 6 characters.';
        case 'requires-recent-login':
          return 'Please log out and log back in, then try again.';
        case 'network-request-failed':
          return 'No internet connection. Please try again.';
        default:
          return e.message ?? 'Could not update your password.';
      }
    }
  }

  /// Updates the account email. Sends a verification link to the NEW
  /// address first (Firebase's recommended flow) rather than switching
  /// immediately — the new address only becomes the sign-in email once the
  /// user taps that link, so it can't be swapped in by someone who doesn't
  /// actually control the new inbox. Requires the current password to
  /// re-authenticate.
  static Future<String?> updateEmail({
    required String currentPassword,
    required String newEmail,
  }) async {
    final reauthError = await _reauthenticate(currentPassword);
    if (reauthError != null) return reauthError;

    try {
      await _auth.currentUser!.verifyBeforeUpdateEmail(newEmail.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'An account with this email already exists.';
        case 'invalid-email':
          return 'That email address looks invalid.';
        case 'requires-recent-login':
          return 'Please log out and log back in, then try again.';
        case 'network-request-failed':
          return 'No internet connection. Please try again.';
        default:
          return e.message ?? 'Could not update your email.';
      }
    }
  }

  static Future<void> logout() => _auth.signOut();
}