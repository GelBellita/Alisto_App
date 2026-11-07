import 'package:flutter_test/flutter_test.dart';

import 'package:alisto_app/models/app_models.dart';

void main() {
  final now = DateTime.utc(2026, 10, 22, 10, 0, 0);

  AlertModel alert({
    String status = 'SENT',
    bool acknowledged = false,
    String type = 'emergency',
    DateTime? at,
    bool noTime = false,
  }) =>
      AlertModel(
        id: 'a1',
        title: 'Unknown emergency',
        time: '',
        lines: const [],
        type: type,
        acknowledged: acknowledged,
        status: status,
        triggeredAt: noTime ? null : (at ?? now.subtract(const Duration(seconds: 10))),
      );

  group('when the floating emergency card opens', () {
    test('a fresh, sent, unacknowledged emergency opens it', () {
      expect(alert().needsEmergencyCard(now, {}), isTrue);
    });

    test('never twice for the same emergency', () {
      expect(alert().needsEmergencyCard(now, {'a1'}), isFalse);
    });

    test('not once someone has acknowledged it', () {
      expect(alert(acknowledged: true).needsEmergencyCard(now, {}), isFalse);
    });

    test('not for a false alarm or before the SMS went out', () {
      expect(alert(status: 'CANCELLED').needsEmergencyCard(now, {}), isFalse);
      expect(alert(status: 'PENDING').needsEmergencyCard(now, {}), isFalse);
      expect(alert(status: '').needsEmergencyCard(now, {}), isFalse);
    });

    test('not for old emergencies, such as ones the device uploaded after being offline', () {
      expect(alert(at: now.subtract(const Duration(minutes: 5))).needsEmergencyCard(now, {}), isFalse);
      expect(alert(at: now.subtract(const Duration(hours: 6))).needsEmergencyCard(now, {}), isFalse);
    });

    test('still opens until the alarm window (3 minutes) is over', () {
      expect(alert(at: now.subtract(const Duration(minutes: 2, seconds: 59))).needsEmergencyCard(now, {}), isTrue);
      expect(alert(at: now.subtract(const Duration(minutes: 3, seconds: 1))).needsEmergencyCard(now, {}), isFalse);
    });

    test('a little phone/device clock difference is tolerated, a big one is not', () {
      expect(alert(at: now.add(const Duration(seconds: 10))).needsEmergencyCard(now, {}), isTrue);
      expect(alert(at: now.add(const Duration(minutes: 10))).needsEmergencyCard(now, {}), isFalse);
    });

    test('no timestamp yet, or not an emergency, never opens it', () {
      expect(alert(noTime: true).needsEmergencyCard(now, {}), isFalse);
      expect(alert(type: 'medicine').needsEmergencyCard(now, {}), isFalse);
    });
  });
}
