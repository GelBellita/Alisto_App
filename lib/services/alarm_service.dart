import 'package:flutter/services.dart';

/// Bridges to native Android code (EmergencyAlarmService.kt, launched via
/// MainActivity's MethodChannel handler) to run a real "keep buzzing
/// until someone notices" alarm -- continuous vibration + looping ALARM-
/// stream tone, capped at 3 minutes -- while the app is open in the
/// foreground. The SAME service also starts independently, straight from
/// native code (AlistoMessagingService.kt's FCM receiver), when a push
/// arrives while the app is backgrounded or fully killed -- this class
/// only covers the foreground path, where a Flutter engine exists to
/// call a MethodChannel on at all.
class AlarmService {
  static const _channel = MethodChannel('alisto/alarm');

  static Future<void> start({required String title, required String body}) async {
    try {
      await _channel.invokeMethod('start', {'title': title, 'body': body});
    } catch (_) {
      // Best-effort -- a failed native alarm should never block showing
      // the emergency dialog itself.
    }
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stop');
    } catch (_) {}
  }
}
