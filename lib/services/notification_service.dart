import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'firestore_service.dart';

/// Must be a TOP-LEVEL (or static) function -- Firebase Messaging calls this
/// in a separate isolate when a push notification arrives while the app is
/// fully backgrounded/killed, so it can't be a normal instance method.
///
/// Intentionally does nothing: starting the real alarm (continuous
/// vibration + looping tone, see EmergencyAlarmService.kt) for a
/// backgrounded/killed app is handled entirely in native code instead,
/// by AlistoMessagingService.kt's own independent FCM receiver -- a
/// background Dart isolate's MethodChannel has no engine-scoped native
/// handler to reach (MainActivity's channel is tied to MainActivity's
/// own FlutterEngine, not this headless one), so trying to do it from
/// here wouldn't reliably work anyway. This handler stays registered
/// only because FirebaseMessaging.onBackgroundMessage() requires one.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Intentionally empty -- see comment above.
}

/// Wraps Firebase Cloud Messaging: requests notification permission, keeps
/// this device's FCM token saved on the user's account (so the Raspberry
/// Pi -- via firestore_backend.py's send_emergency_push(), using the Admin
/// SDK -- knows where to push emergency alerts), and shows a message when
/// one arrives while the app is open in the foreground (the OS handles
/// showing it automatically in background/killed states).
class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// A late-set callback the UI layer (main.dart) can hook to show a
  /// SnackBar/dialog for a foreground message -- kept out of this service
  /// itself so it doesn't need a BuildContext.
  static void Function(RemoteMessage message)? onForegroundMessage;

  static bool _listening = false; // the listeners below are added only once
  static String? _registeredFor; // the account the token was last saved for

  /// What happened the last time this device tried to register for pushes,
  /// in plain words ("Token saved", or the exact error). Shown on the
  /// Profile screen so a failure is visible on the phone: before this, an
  /// error only went to debugPrint and a stale token in Firestore (the Pi
  /// then gets "NotRegistered" for it) was the only symptom.
  static final ValueNotifier<String> status = ValueNotifier('Not started yet');

  /// Called once a user is logged in -- from main.dart's AuthGate (app opened
  /// with a saved session) AND from AuthRoutingGate (right after logging in or
  /// signing up). The second one matters: logging in replaces the whole
  /// screen stack, which removes AuthGate, so with only the first call a
  /// fresh login never registered a token until the app was closed and
  /// reopened -- the phone kept a stale token in Firestore and the Pi got
  /// "NotRegistered" for every push. Safe to call on every rebuild: it only
  /// does the work once per signed-in account (a different account logging
  /// in on the same phone registers again).
  static Future<void> init() async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null || _registeredFor == uid) return;
    _registeredFor = uid;

    if (!_listening) {
      _listening = true;
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // The OS can rotate this token (app reinstall, data clear, etc.) --
      // keep Firestore in sync whenever that happens, not just at startup.
      _messaging.onTokenRefresh.listen(_saveToken);

      FirebaseMessaging.onMessage.listen((message) {
        onForegroundMessage?.call(message);
      });
    }

    await refreshToken();
  }

  /// Asks for permission, gets this phone's FCM token and saves it on the
  /// signed-in account, recording each outcome in [status]. Can be called
  /// again at any time ("Try again" on the Profile screen).
  ///
  /// Each step is independently try/caught -- a failure in one (e.g.
  /// requestPermission() erroring on some OEM/Android-version combination)
  /// must never prevent the others from running. Real testing hit exactly
  /// this: an unguarded requestPermission() call throwing meant
  /// getToken()/saveToken() never even ran, so the token in Firestore
  /// silently went stale after a reinstall.
  static Future<void> refreshToken() async {
    status.value = 'Checking notification permission…';
    var permission = 'unknown';
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      permission = settings.authorizationStatus.name;
    } catch (e) {
      permission = 'error ($e)';
      debugPrint('NotificationService: requestPermission failed: $e');
    }

    status.value = 'Getting this phone\'s push token…';
    String? token;
    try {
      token = await _messaging.getToken();
    } catch (e) {
      debugPrint('NotificationService: getToken failed: $e');
      status.value = 'Could not get a push token: $e (permission: $permission)';
      return;
    }
    if (token == null) {
      debugPrint('NotificationService: getToken() returned null');
      status.value =
          'Firebase returned no push token (permission: $permission).';
      return;
    }

    final error = await _saveToken(token);
    final tail = token.substring(token.length > 6 ? token.length - 6 : 0);
    status.value = error == null
        ? 'Ready. Token …$tail saved to your account (permission: $permission).'
        : 'Token …$tail found but NOT saved: $error';
  }

  /// Returns null on success, or the error text.
  static Future<String?> _saveToken(String token) async {
    try {
      await FirestoreService.saveFcmToken(token);
      return null;
    } catch (e) {
      // Best-effort -- a failed token save just means this device won't
      // get pushes until the next successful one (e.g. next app open),
      // not something that should crash startup.
      debugPrint('NotificationService: failed to save FCM token: $e');
      return e.toString();
    }
  }
}
