import 'package:flutter_test/flutter_test.dart';
import 'package:alisto_app/models/app_models.dart';

// The alert shows HOW it was triggered only for the SOS button. A voice alert
// shows the emergency category (title + message) and no phrase: the words the
// device heard go in the SMS only.
void main() {
  AlertModel alert({String triggerType = ''}) => AlertModel(
        id: 'a1',
        title: 'Fall Injury emergency',
        time: 'Today, 7:00 PM',
        lines: const ['ALISTO ALERT!'],
        triggerType: triggerType,
      );

  test('the SOS button shows "Triggered by: SOS button"', () {
    expect(alert(triggerType: 'BUTTON').detailLine, 'Triggered by: SOS button');
    expect(alert(triggerType: 'button').detailLine, 'Triggered by: SOS button');
  });

  test('a voice alert shows no extra line (category only, no phrase)', () {
    expect(alert(triggerType: 'VOICE').detailLine, isNull);
  });

  test('old alerts without a trigger type show nothing', () {
    expect(alert().detailLine, isNull);
  });

  test('the push notification builds the same line from a plain string', () {
    expect(AlertModel.detailLineFor(triggerType: 'BUTTON'),
        'Triggered by: SOS button');
    expect(AlertModel.detailLineFor(triggerType: 'VOICE'), isNull);
    expect(AlertModel.detailLineFor(), isNull);
  });
}
