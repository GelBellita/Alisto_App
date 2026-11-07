import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alisto_app/models/care_plan_models.dart';

void main() {
  // 2026-11-01 12:00 Philippine time
  final now = DateTime.utc(2026, 11, 1, 4, 0);
  Map<String, dynamic> sub(DateTime end, {String status = 'active'}) => {
        'status': status,
        'current_period_end': Timestamp.fromDate(end),
      };

  group('plan status (same rules as the website)', () {
    test('no subscription = No Plan', () {
      final s = computePlanState(sub: null, now: now);
      expect(s.status, PlanStatus.none);
      expect(s.label, 'No Plan');
      expect(s.paidUntil, '—');
    });

    test('far from the end = Active', () {
      final s = computePlanState(sub: sub(DateTime.utc(2026, 11, 20, 4)), now: now);
      expect(s.status, PlanStatus.active);
      expect(s.label, 'Active');
      expect(s.headline, 'Renews in 19 days');
      expect(s.paidUntil, 'November 20, 2026');
    });

    test('5 days or less = Expiring', () {
      final s = computePlanState(sub: sub(DateTime.utc(2026, 11, 6, 4)), now: now);
      expect(s.status, PlanStatus.expiring);
      expect(s.daysLeft, 5);
      expect(s.needsAttention, isTrue);
    });

    test('1 day wording is singular, same day says today', () {
      expect(computePlanState(sub: sub(DateTime.utc(2026, 11, 2, 4)), now: now).headline, 'Renews in 1 day');
      expect(computePlanState(sub: sub(DateTime.utc(2026, 11, 1, 10)), now: now).headline, 'Renews today');
    });

    test('past the end = Expired, with how long ago', () {
      final s = computePlanState(sub: sub(DateTime.utc(2026, 10, 29, 4)), now: now);
      expect(s.status, PlanStatus.expired);
      expect(s.label, 'Expired');
      expect(s.headline, 'Expired 3 days ago');
    });

    test('cancelled is called Cancelled even before the end date', () {
      final s = computePlanState(sub: sub(DateTime.utc(2026, 12, 1), status: 'cancelled'), now: now);
      expect(s.status, PlanStatus.expired);
      expect(s.label, 'Cancelled');
    });

    test('a payment under review only matters when there is no running plan', () {
      expect(computePlanState(sub: null, hasPending: true, now: now).label, 'Pending');
      expect(computePlanState(sub: sub(DateTime.utc(2026, 10, 1)), hasPending: true, now: now).status, PlanStatus.pending);
      expect(computePlanState(sub: sub(DateTime.utc(2026, 11, 20, 4)), hasPending: true, now: now).status, PlanStatus.active);
    });
  });

  group('payment form rules', () {
    test('GCash reference must be exactly 13 digits', () {
      expect(isValidGcashReference('1234567890123'), isTrue);
      expect(isValidGcashReference('123456789012'), isFalse);
      expect(isValidGcashReference('12345678901234'), isFalse);
      expect(isValidGcashReference('12345678901ab'), isFalse);
    });

    test('amount must equal price x months', () {
      final total = planTotal(55, 3);
      expect(total, 165);
      expect(amountMatches(parseAmount('165'), total), isTrue);
      expect(amountMatches(parseAmount('165.00'), total), isTrue);
      expect(amountMatches(parseAmount('1,65'), total), isTrue); // comma stripped, same as the website
      expect(amountMatches(parseAmount('55'), total), isFalse);
      expect(amountMatches(parseAmount('abc'), total), isFalse);
      expect(amountMatches(parseAmount(''), total), isFalse);
    });

    test('totals do not drift on cents', () {
      expect(planTotal(55.5, 3), 166.5);
      expect(planTotal(0.1, 3), 0.3);
    });
  });

  group('formatting', () {
    test('peso', () {
      expect(formatPeso(55), '₱55');
      expect(formatPeso(1234), '₱1,234');
      expect(formatPeso(55.5), '₱55.50');
      expect(formatPeso(1234567.25), '₱1,234,567.25');
    });
    test('plan length', () {
      expect(planLengthText(1), '1 month');
      expect(planLengthText(12), '12 months');
    });
  });

  group('settings parsing', () {
    test('plan falls back to the website defaults', () {
      final p = CarePlanInfo.fromMap(null);
      expect(p.price, 55);
      expect(p.name, 'Alisto Care Plan');
      expect(CarePlanInfo.fromMap({'price': 99, 'name': 'Basic'}).price, 99);
      expect(CarePlanInfo.fromMap({'price': 'oops'}).price, 55);
    });

    test('QR settings: one entry per plan length, missing ones default', () {
      final qr = planQrFromDoc({
        '3': {'gcash_name': 'Juan', 'gcash_number': '0917', 'qr_image_url': 'https://x/y.jpg'},
      });
      expect(qr.keys, kPlanMonthOptions);
      expect(qr[3]!.gcashName, 'Juan');
      expect(qr[3]!.qrImageUrl, 'https://x/y.jpg');
      expect(qr[1]!.gcashName, 'ALISTO');
      expect(qr[1]!.gcashNumber, '');
    });
  });

  group('GCash number under the QR', () {
    test('copies digits only so it pastes straight into GCash', () {
      expect(gcashNumberForCopy('0969 073 8742'), '09690738742');
      expect(gcashNumberForCopy('0969-073-8742'), '09690738742');
      expect(gcashNumberForCopy('09690738742'), '09690738742');
      expect(gcashNumberForCopy('+63 969 073 8742'), '+639690738742');
    });

    test('a plan with no number of its own falls back, in order', () {
      final qr = planQrFromDoc({
        '3': {'gcash_number': '0917 000 0000', 'gcash_name': 'Admin Plan'},
      });

      // 1) the plan's own number wins
      final a = withGcashFallback(qr, {'gcash_number': '0999'}, defaultNumber: '09690738742');
      expect(a[3]!.gcashNumber, '0917 000 0000');
      expect(a[3]!.gcashName, 'Admin Plan');

      // 2) otherwise the admin's general GCash number (and name)
      expect(a[1]!.gcashNumber, '0999');
      final b = withGcashFallback(qr, {'gcash_number': '0999', 'gcash_name': 'Juan'}, defaultNumber: '09690738742');
      expect(b[1]!.gcashName, 'Juan');

      // 3) otherwise the number built into the app
      final c = withGcashFallback(qr, null, defaultNumber: '09690738742');
      expect(c[1]!.gcashNumber, '09690738742');
      expect(c[12]!.gcashNumber, '09690738742');
      expect(c[1]!.gcashName, 'ALISTO');
    });
  });

  group('payments', () {
    PaymentRecord pay(String id, String status, DateTime? at) => PaymentRecord.fromMap(id, {
          'status': status,
          'months': 1,
          'amount': 55,
          'created_at': at == null ? null : Timestamp.fromDate(at),
          'reject_reason': 'Amount does not match',
        });

    test('newest first, unsaved timestamp on top', () {
      final list = sortPayments([
        pay('a', 'approved', DateTime.utc(2026, 9, 1)),
        pay('b', 'pending', null),
        pay('c', 'rejected', DateTime.utc(2026, 10, 1)),
      ]);
      expect(list.map((p) => p.id), ['b', 'c', 'a']);
    });

    test('rejection banner only when the newest payment was rejected', () {
      final rejectedNewest = sortPayments([
        pay('a', 'approved', DateTime.utc(2026, 9, 1)),
        pay('c', 'rejected', DateTime.utc(2026, 10, 1)),
      ]);
      expect(latestRejection(rejectedNewest)?.id, 'c');

      final fixed = sortPayments([
        pay('a', 'rejected', DateTime.utc(2026, 9, 1)),
        pay('c', 'approved', DateTime.utc(2026, 10, 1)),
      ]);
      expect(latestRejection(fixed), isNull);
      expect(latestRejection([]), isNull);
    });

    test('payment number falls back to the id like the website', () {
      expect(PaymentRecord.fromMap('abcdef123', {}).paymentNo, 'PAY-ABCDEF');
    });
  });
}
