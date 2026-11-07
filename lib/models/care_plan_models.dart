// ALISTO Care Plan: the data shapes and the plan-status rules the family
// app uses. They mirror the website's care_plan_service.py field for field
// (same Firestore documents), so a payment sent from the app shows up on the
// admin's Subscriptions page exactly like one sent from the website.
//
//   care_plan/default            name, price, currency, description
//   app_settings/plan_qr_codes   {"1": {gcash_name, gcash_number, qr_image_url}, "3": ...}
//   subscription/{elder_id}      status, current_period_end, ...
//   payment/{id}                 one per payment, 'pending' until an admin decides

import 'package:cloud_firestore/cloud_firestore.dart';

const List<int> kPlanMonthOptions = [1, 3, 6, 12];
const int kExpiringSoonDays = 5;
const Duration _phOffset = Duration(hours: 8); // Philippine time, UTC+8

const List<String> _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July',
  'August', 'September', 'October', 'November', 'December',
];

// ---------------------------------------------------------
// FORMATTING + VALIDATION (same rules as the website's pay form)
// ---------------------------------------------------------
String formatPeso(double amount) {
  final whole = amount == amount.roundToDouble();
  final text = whole ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2);
  final parts = text.split('.');
  final grouped = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '₱${parts.length > 1 ? '$grouped.${parts[1]}' : grouped}';
}

String formatPlanDate(DateTime date) {
  final ph = date.toUtc().add(_phOffset);
  return '${_monthNames[ph.month - 1]} ${ph.day.toString().padLeft(2, '0')}, ${ph.year}';
}

String planLengthText(int months) => '$months month${months == 1 ? '' : 's'}';

/// GCash reference numbers are exactly 13 digits.
bool isValidGcashReference(String value) => RegExp(r'^\d{13}$').hasMatch(value);

/// The amount typed by the family, or null if it isn't a number.
double? parseAmount(String raw) =>
    double.tryParse(raw.replaceAll(',', '').trim());

/// Matches validate_payment_submission() on the website: what the family says
/// they sent must equal price x months, so a "6 months" request is never
/// backed by a 1-month payment.
bool amountMatches(double? amount, double expected) =>
    amount != null && (amount - expected).abs() < 0.005;

double planTotal(double unitPrice, int months) =>
    (unitPrice * months * 100).round() / 100;

// ---------------------------------------------------------
// PLAN + PAYMENT SETTINGS
// ---------------------------------------------------------
class CarePlanInfo {
  final String name;
  final double price; // per month
  final String currency;
  final String description;

  const CarePlanInfo({
    required this.name,
    required this.price,
    required this.currency,
    required this.description,
  });

  // The website's DEFAULT_PLAN, used until the admin saves a plan.
  static const CarePlanInfo defaults = CarePlanInfo(
    name: 'Alisto Care Plan',
    price: 55,
    currency: 'PHP',
    description:
        'Emergency alerts, live location, and medicine reminders for one '
        'ALISTO device.',
  );

  factory CarePlanInfo.fromMap(Map<String, dynamic>? m) {
    if (m == null) return defaults;
    final price = m['price'];
    return CarePlanInfo(
      name: (m['name'] as String?)?.trim().isNotEmpty == true
          ? m['name'] as String
          : defaults.name,
      price: price is num ? price.toDouble() : defaults.price,
      currency: (m['currency'] as String?) ?? defaults.currency,
      description: (m['description'] as String?)?.trim().isNotEmpty == true
          ? m['description'] as String
          : defaults.description,
    );
  }
}

class PlanQrInfo {
  final String gcashName;
  final String gcashNumber;
  final String qrImageUrl;

  const PlanQrInfo({
    required this.gcashName,
    required this.gcashNumber,
    required this.qrImageUrl,
  });

  static const PlanQrInfo defaults = PlanQrInfo(
    gcashName: 'ALISTO',
    gcashNumber: '',
    qrImageUrl: '',
  );

  factory PlanQrInfo.fromMap(Map<String, dynamic>? m) {
    if (m == null) return defaults;
    String text(String key, String fallback) {
      final v = m[key];
      return v is String && v.trim().isNotEmpty ? v.trim() : fallback;
    }

    return PlanQrInfo(
      gcashName: text('gcash_name', defaults.gcashName),
      gcashNumber: text('gcash_number', ''),
      qrImageUrl: text('qr_image_url', ''),
    );
  }
}

/// Digits only ("0917 123 4567" -> "09171234567"), so what the family copies
/// pastes straight into GCash's "send to number" field.
String gcashNumberForCopy(String number) => number.replaceAll(RegExp(r'[^0-9+]'), '');

/// A plan length with no GCash number of its own uses the admin's general
/// GCash number (app_settings/payment_methods), and failing that
/// [defaultNumber] (kDefaultGcashNumber in care_plan_service.dart).
Map<int, PlanQrInfo> withGcashFallback(
  Map<int, PlanQrInfo> qr,
  Map<String, dynamic>? paymentMethods, {
  String defaultNumber = '',
}) {
  String text(String key) {
    final v = paymentMethods?[key];
    return v is String ? v.trim() : '';
  }

  final methodNumber = text('gcash_number');
  final methodName = text('gcash_name');
  return {
    for (final e in qr.entries)
      e.key: PlanQrInfo(
        gcashName: e.value.gcashName == PlanQrInfo.defaults.gcashName && methodName.isNotEmpty
            ? methodName
            : e.value.gcashName,
        gcashNumber: e.value.gcashNumber.isNotEmpty
            ? e.value.gcashNumber
            : (methodNumber.isNotEmpty ? methodNumber : defaultNumber),
        qrImageUrl: e.value.qrImageUrl,
      ),
  };
}

/// {1: ..., 3: ..., 6: ..., 12: ...}; a plan length the admin hasn't set a
/// QR for falls back to the defaults.
Map<int, PlanQrInfo> planQrFromDoc(Map<String, dynamic>? data) {
  return {
    for (final months in kPlanMonthOptions)
      months: PlanQrInfo.fromMap(
        (data?['$months'] is Map)
            ? Map<String, dynamic>.from(data!['$months'] as Map)
            : null,
      ),
  };
}

// ---------------------------------------------------------
// PLAN STATUS (same wording and rules as subscription_state() on the web)
// ---------------------------------------------------------
enum PlanStatus { active, expiring, expired, none, pending }

class PlanState {
  final PlanStatus status;
  final String label; // Active | Expiring | Expired | Cancelled | No Plan | Pending
  final String headline; // "Renews in 12 days"
  final String paidUntil; // "November 15, 2026" or "—"
  final int daysLeft;
  final bool hasPending;

  const PlanState({
    required this.status,
    required this.label,
    required this.headline,
    required this.paidUntil,
    required this.daysLeft,
    required this.hasPending,
  });

  /// Whether the family should be nudged to pay (Home banner).
  bool get needsAttention =>
      status == PlanStatus.expiring ||
      status == PlanStatus.expired ||
      status == PlanStatus.none;
}

DateTime _dateOnlyPh(DateTime d) {
  final ph = d.toUtc().add(_phOffset);
  return DateTime.utc(ph.year, ph.month, ph.day);
}

DateTime? _timestampToDate(dynamic value) =>
    value is Timestamp ? value.toDate() : (value is DateTime ? value : null);

/// [sub] is the subscription/{elder_id} document (null if none yet).
/// [hasPending] is true if the family has a payment waiting for review.
PlanState computePlanState({
  Map<String, dynamic>? sub,
  bool hasPending = false,
  DateTime? now,
}) {
  now ??= DateTime.now();
  final end = _timestampToDate(sub?['current_period_end']);
  final cancelled = sub?['status'] == 'cancelled';

  PlanState state;
  if (end != null && end.isAfter(now) && !cancelled) {
    final daysLeft = _dateOnlyPh(end).difference(_dateOnlyPh(now)).inDays;
    final left = daysLeft < 0 ? 0 : daysLeft;
    final expiring = left <= kExpiringSoonDays;
    state = PlanState(
      status: expiring ? PlanStatus.expiring : PlanStatus.active,
      label: expiring ? 'Expiring' : 'Active',
      headline: left == 0
          ? 'Renews today'
          : 'Renews in $left day${left == 1 ? '' : 's'}',
      paidUntil: formatPlanDate(end),
      daysLeft: left,
      hasPending: hasPending,
    );
  } else if (end != null) {
    final ago = _dateOnlyPh(now).difference(_dateOnlyPh(end)).inDays;
    final daysAgo = ago < 0 ? 0 : ago;
    state = PlanState(
      status: PlanStatus.expired,
      label: cancelled ? 'Cancelled' : 'Expired',
      headline: daysAgo == 0
          ? 'Expired today'
          : 'Expired $daysAgo day${daysAgo == 1 ? '' : 's'} ago',
      paidUntil: formatPlanDate(end),
      daysLeft: 0,
      hasPending: hasPending,
    );
  } else {
    state = PlanState(
      status: PlanStatus.none,
      label: 'No Plan',
      headline: 'No active plan yet',
      paidUntil: '—',
      daysLeft: 0,
      hasPending: hasPending,
    );
  }

  if (hasPending &&
      (state.status == PlanStatus.none || state.status == PlanStatus.expired)) {
    return PlanState(
      status: PlanStatus.pending,
      label: 'Pending',
      headline: 'Payment under review',
      paidUntil: state.paidUntil,
      daysLeft: 0,
      hasPending: true,
    );
  }
  return state;
}

// ---------------------------------------------------------
// PAYMENTS
// ---------------------------------------------------------
class PaymentRecord {
  final String id;
  final String paymentNo;
  final int months;
  final double amount;
  final String referenceNo;
  final String status; // pending | approved | rejected
  final DateTime? createdAt;
  final String rejectReason;
  final String adminNote;
  final DateTime? periodEnd; // set when approved: the plan now runs until here

  const PaymentRecord({
    required this.id,
    required this.paymentNo,
    required this.months,
    required this.amount,
    required this.referenceNo,
    required this.status,
    required this.createdAt,
    required this.rejectReason,
    required this.adminNote,
    this.periodEnd,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  factory PaymentRecord.fromMap(String id, Map<String, dynamic> m) {
    final amount = m['amount'];
    final months = m['months'];
    return PaymentRecord(
      id: id,
      paymentNo: (m['payment_no'] as String?) ?? 'PAY-${id.substring(0, id.length < 6 ? id.length : 6).toUpperCase()}',
      months: months is num ? months.toInt() : 1,
      amount: amount is num ? amount.toDouble() : 0,
      referenceNo: (m['reference_no'] as String?) ?? '',
      status: (m['status'] as String?) ?? 'pending',
      createdAt: _timestampToDate(m['created_at']),
      rejectReason: (m['reject_reason'] as String?) ?? '',
      adminNote: (m['admin_note'] as String?) ?? '',
      periodEnd: _timestampToDate(m['period_end']),
    );
  }
}

/// Newest first; rows still waiting for the server timestamp go on top.
List<PaymentRecord> sortPayments(Iterable<PaymentRecord> payments) {
  final list = payments.toList();
  list.sort((a, b) {
    final at = a.createdAt, bt = b.createdAt;
    if (at == null && bt == null) return 0;
    if (at == null) return -1;
    if (bt == null) return 1;
    return bt.compareTo(at);
  });
  return list;
}

/// Same rule as latest_rejection() on the web: only when the MOST RECENT
/// payment was rejected is there something to tell the family about.
PaymentRecord? latestRejection(List<PaymentRecord> sortedNewestFirst) {
  if (sortedNewestFirst.isEmpty) return null;
  final newest = sortedNewestFirst.first;
  return newest.isRejected ? newest : null;
}
