import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

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

  static bool _initialized = false;

  /// Called after confirming the user is logged in (see main.dart's
  /// AuthGate) -- registering a token against no account would have
  /// nowhere to save it. Safe to call from a widget's build() on every
  /// rebuild: guarded so the actual setup only ever runs once per app
  /// session.
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Each step below is independently try/caught -- a failure in one
    // (e.g. requestPermission() erroring on some OEM/Android-version
    // combination) must never prevent the others from running. Real
    // testing hit exactly this: an unguarded requestPermission() call
    // throwing meant getToken()/saveToken() below it never even ran, so
    // the token in Firestore silently went stale after a reinstall.
    try {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint('NotificationService: requestPermission failed: $e');
    }

    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveToken(token);
      } else {
        debugPrint('NotificationService: getToken() returned null');
      }
    } catch (e) {
      debugPrint('NotificationService: getToken failed: $e');
    }

    // The OS can rotate this token (app reinstall, data clear, etc.) --
    // keep Firestore in sync whenever that happens, not just at startup.
    _messaging.onTokenRefresh.listen(_saveToken);

    FirebaseMessaging.onMessage.listen((message) {
      onForegroundMessage?.call(message);
    });
  }

  static Future<void> _saveToken(String token) async {
    try {
      await FirestoreService.saveFcmToken(token);
    } catch (e) {
      // Best-effort -- a failed token save just means this device won't
      // get pushes until the next successful one (e.g. next app open),
      // not something that should crash startup.
      debugPrint('NotificationService: failed to save FCM token: $e');
    }
  }
}
