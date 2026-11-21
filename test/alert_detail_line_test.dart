import 'package:flutter_test/flutter_test.dart';
import 'package:alisto_app/models/app_models.dart';

// The alert shows HOW it was triggered: the SOS button, or the phrase the
// device heard. Alerts from before this was recorded show nothing extra.
void main() {
  AlertModel alert({String triggerType = '', String? phrase}) => AlertModel(
        id: 'a1',
        title: 'Fall Injury emergency',
        time: 'Today, 7:00 PM',
        lines: const ['ALISTO ALERT!'],
        triggerType: triggerType,
        detectedPhrase: phrase,
      );

  test('voice alert shows the phrase the device heard', () {
    expect(
      alert(triggerType: 'VOICE', phrase: 'alistoon na hula-go.').detailLine,
      'Detected phrase: “alistoon na hula-go.”',
    );
  });

  test('the SOS button shows "Triggered by: SOS button", never a phrase', () {
    expect(alert(triggerType: 'BUTTON').detailLine, 'Triggered by: SOS button');
    expect(
      alert(triggerType: 'button', phrase: 'ignored').detailLine,
      'Triggered by: SOS button',
    );
  });

  test('old alerts with neither field show nothing (no made-up value)', () {
    expect(alert().detailLine, isNull);
    expect(alert(triggerType: 'VOICE').detailLine, isNull);
    expect(alert(triggerType: 'VOICE', phrase: '   ').detailLine, isNull);
  });

  test('a phrase is trimmed', () {
    expect(
      alert(phrase: '  tabang  ').detailLine,
      'Detected phrase: “tabang”',
    );
  });

  test('the push notification builds the same line from plain strings', () {
    expect(
      AlertModel.detailLineFor(triggerType: 'VOICE', detectedPhrase: 'tabang'),
      'Detected phrase: “tabang”',
    );
    expect(AlertModel.detailLineFor(triggerType: 'BUTTON'),
        'Triggered by: SOS button');
    expect(AlertModel.detailLineFor(), isNull);
  });
}
