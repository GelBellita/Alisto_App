import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

import 'theme/app_theme.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'screens/auth_screens.dart';
import 'widgets/emergency_alert_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AlistoApp());
}

/// App-wide keys so NotificationService (which has no BuildContext of its
/// own) can act on a push that arrives while the app is open in the
/// foreground -- background/killed-state notifications are shown by the OS
/// automatically and don't need either of these.
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class AlistoApp extends StatelessWidget {
  const AlistoApp({super.key});

  @override
  Widget build(BuildContext context) {
    NotificationService.onForegroundMessage = (message) {
      // Routine (non-emergency) notice from the website -- e.g. an admin
      // unregistering this elder's device (see admin_routes.py's
      // _notify_family_device_unregistered()). Sent WITH a `notification`
      // payload (unlike the emergency push below), so a backgrounded/
      // killed app already gets it via Android's own system tray; this
      // branch only covers the foreground case, where FCM hands the
      // message to the app instead of auto-showing anything. A SnackBar
      // is enough here -- this is worth knowing, not a "check on someone
      // right now" situation, so it doesn't get the alarm dialog treatment.
      if (message.data['type'] == 'device_unregistered') {
        rootScaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
          content: Text(message.notification?.body ?? 'A device was unregistered.'),
          duration: const Duration(seconds: 6),
        ));
        return;
      }

      // firestore_backend.py's send_emergency_push() sends DATA-ONLY
      // messages (no top-level `notification` field) -- see that
      // function's doc comment for why -- so title/body live in `data`
      // now, not `message.notification`.
      if (message.data['type'] != 'emergency') return;
      final title = message.data['title'] as String? ?? 'ALISTO Emergency Alert';
      final body = message.data['body'] as String? ?? '';

      final navigatorContext = rootNavigatorKey.currentState?.overlay?.context;
      if (navigatorContext == null) return;

      // Emergency pushes get full-attention treatment (loud alarm tone +
      // continuous vibration + a floating card that must be explicitly
      // acknowledged) instead of a easy-to-miss SnackBar -- this is a
      // "please check on someone right now" alert, not a routine update.
      //
      // NOT starting AlarmService here: AlistoMessagingService.kt (native
      // Android) already receives this same FCM message independently
      // and starts EmergencyAlarmService itself, in EVERY app state
      // (foreground included -- Firebase delivers to onMessageReceived()
      // regardless of foreground/background). Also calling
      // AlarmService.start() from here double-started the same service,
      // leaving an orphaned MediaPlayer that "OK, I saw this" couldn't
      // stop (only the second instance got released). This handler now
      // only owns showing the dialog UI.
      showDialog(
        context: navigatorContext,
        barrierDismissible: false,
        builder: (_) => EmergencyAlertDialog(
          title: title,
          body: body,
          alertId: message.data['alert_id'],
        ),
      );
    };

    return MaterialApp(
      title: 'Alisto',
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavigatorKey,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      theme: AppTheme.light,
      home: const AuthGate(),
    );
  }
}

/// Runs once at app startup: if a session already exists (the user is
/// still logged in from a previous visit), skip straight past the splash
/// and onboarding screens and route to wherever they left off — role
/// selection, device registration, or the dashboard. If not logged in,
/// show the normal splash -> welcome flow.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData) {
          return const SplashScreen();
        }
        // Fire-and-forget -- init() is idempotent (guarded internally), so
        // it's safe to call on every rebuild of this StreamBuilder, not
        // just the first time a logged-in user is seen.
        NotificationService.init();
        return const AuthRoutingGate();
      },
    );
  }
}
