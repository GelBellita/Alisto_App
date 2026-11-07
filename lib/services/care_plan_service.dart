import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/care_plan_models.dart';
import 'firestore_service.dart';

/// The website's address, used only to load a QR image the admin uploaded
/// (saved as a relative path like "/static/uploads/qr.jpg"). Leave empty to
/// always show the QR bundled with the app (assets/images/alisto_qr.jpg).
const String kWebsiteBaseUrl = '';

/// The GCash number shown under the QR when the admin hasn't saved one on the
/// website (Subscriptions page), so families always see a number they can copy.
/// A number the admin saves on the website takes priority over this one.
const String kDefaultGcashNumber = '09690738742';

/// Thrown with a message that is safe to show to the family.
class CarePlanException implements Exception {
  final String message;
  const CarePlanException(this.message);
  @override
  String toString() => message;
}

class CarePlanService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // How long a payment submission waits for the server before it is treated
  // as "saved on this phone, will send itself when the internet is back".
  static const Duration _serverWait = Duration(seconds: 12);

  // -------------------------------------------------------
  // READS (each falls back to defaults on error, so the screen still opens)
  // -------------------------------------------------------
  static Stream<CarePlanInfo> planStream() {
    return _db
        .collection('care_plan')
        .doc('default')
        .snapshots()
        .map((s) => CarePlanInfo.fromMap(s.data()))
        .transform(StreamTransformer.fromHandlers(
          handleError: (e, st, sink) => sink.add(CarePlanInfo.defaults),
        ));
  }

  // The admin's general payment methods (app_settings/payment_methods), read
  // once: only used to fill in a GCash number the per-plan QR settings lack.
  static Future<Map<String, dynamic>?>? _paymentMethods;

  static Future<Map<String, dynamic>?> _loadPaymentMethods() {
    return _paymentMethods ??= _db
        .collection('app_settings')
        .doc('payment_methods')
        .get()
        .then<Map<String, dynamic>?>((s) => s.data())
        .catchError((_) => null);
  }

  static Stream<Map<int, PlanQrInfo>> qrStream() {
    return _db
        .collection('app_settings')
        .doc('plan_qr_codes')
        .snapshots()
        .map((s) => planQrFromDoc(s.data()))
        .transform(StreamTransformer<Map<int, PlanQrInfo>, Map<int, PlanQrInfo>>.fromHandlers(
          handleError: (e, st, sink) => sink.add(planQrFromDoc(null)),
        ))
        .asyncMap(
          (qr) async => withGcashFallback(
            qr,
            await _loadPaymentMethods(),
            defaultNumber: kDefaultGcashNumber,
          ),
        );
  }

  /// subscription/{elder_id}; null when there isn't one yet.
  static Stream<Map<String, dynamic>?> subscriptionStream(String elderId) {
    return _db
        .collection('subscription')
        .doc(elderId)
        .snapshots()
        .map((s) => s.data())
        .transform(StreamTransformer.fromHandlers(
          handleError: (e, st, sink) => sink.add(null),
        ));
  }

  /// This account's own payments, newest first.
  static Stream<List<PaymentRecord>> myPaymentsStream() {
    return _db
        .collection('payment')
        .where('paid_by_user_id', isEqualTo: FirestoreService.currentUserId)
        .snapshots()
        .map((q) => sortPayments(q.docs.map((d) => PaymentRecord.fromMap(d.id, d.data()))))
        .transform(StreamTransformer.fromHandlers(
          handleError: (e, st, sink) => sink.add(const <PaymentRecord>[]),
        ));
  }

  // -------------------------------------------------------
  // SUBMIT A PAYMENT
  // -------------------------------------------------------
  /// Records a GCash payment as 'pending' -- the same document the website
  /// writes, so the admin reviews it on the Subscriptions page and approves
  /// or rejects it. Returns a message for the family.
  ///
  /// [unitPrice] is the monthly price shown on the screen; the total the
  /// family typed must equal unitPrice x months (checked here too).
  static Future<String> submitPayment({
    required String elderId,
    required int months,
    required double unitPrice,
    required String amountPaidText,
    required String referenceNo,
    required String payerName,
  }) async {
    final reference = referenceNo.trim();
    final expected = planTotal(unitPrice, months);
    if (!kPlanMonthOptions.contains(months)) {
      throw const CarePlanException('Please choose a plan length.');
    }
    if (!isValidGcashReference(reference)) {
      throw const CarePlanException('GCash reference numbers have 13 digits.');
    }
    if (!amountMatches(parseAmount(amountPaidText), expected)) {
      throw CarePlanException(
        'The amount must be exactly ${formatPeso(expected)} for '
        '${planLengthText(months)}.',
      );
    }

    final uid = FirestoreService.currentUserId;

    // One document per reference number: the same reference can't be used
    // twice, even by two different accounts.
    final marker = _db.collection('payment_reference').doc(reference);
    try {
      if ((await marker.get()).exists) {
        throw const CarePlanException('This reference number was already submitted.');
      }
    } on FirebaseException {
      // Can't tell right now (offline); the rules still stop a duplicate.
    }

    String elderName = '';
    try {
      final elder = await _db.collection('elder_profile').doc(elderId).get();
      elderName = (elder.data()?['full_name'] as String?) ?? '';
    } catch (_) {}

    String familyName = '';
    try {
      final user = await _db.collection('user_account').doc(uid).get();
      familyName = (user.data()?['full_name'] as String?) ?? '';
    } catch (_) {}

    final deviceSerial = await FirestoreService.deviceSerialForCurrentUser();

    final paymentRef = _db.collection('payment').doc();
    final paymentNo = 'PAY-${paymentRef.id.substring(0, 6).toUpperCase()}';
    final payer = payerName.trim().isEmpty ? familyName : payerName.trim();

    final batch = _db.batch();
    batch.set(paymentRef, {
      'payment_no': paymentNo,
      'elder_id': elderId,
      'elder_name': elderName,
      'device_id': deviceSerial,
      'months': months,
      'unit_price': unitPrice,
      'amount': expected,
      'currency': 'PHP',
      'method': 'gcash',
      'reference_no': reference,
      'payer_name': payer,
      'note': '',
      'paid_by_user_id': uid,
      'paid_by_name': familyName,
      'status': 'pending',
      'created_at': FieldValue.serverTimestamp(),
    });
    batch.set(marker, {
      'payment_id': paymentRef.id,
      'user_id': uid,
      'created_at': FieldValue.serverTimestamp(),
    });

    var queuedOffline = false;
    try {
      await batch.commit().timeout(_serverWait);
    } on TimeoutException {
      // Firestore keeps the write and sends it when the connection returns.
      queuedOffline = true;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        // Firestore refused the write: either this reference number was
        // already used (the reference marker already exists), or the app's
        // security rules don't allow payments yet (not published).
        throw const CarePlanException(
          'Could not save the payment (permission denied). If this reference '
          'number is new, the app is not set up for payments yet. Please '
          'contact support.',
        );
      }
      throw CarePlanException('Could not submit the payment (${e.code}). Please try again.');
    }

    // Tells the admin team (their inbox) -- nice to have, never blocks.
    if (!queuedOffline) {
      unawaited(_notifyAdmins(
        paymentId: paymentRef.id,
        paymentNo: paymentNo,
        uid: uid,
        familyName: familyName,
        elderId: elderId,
        elderName: elderName,
        months: months,
        amount: expected,
        reference: reference,
      ));
    }

    return queuedOffline
        ? 'Saved on your phone. It will be sent as soon as you are back online.'
        : 'Payment submitted ($paymentNo). Waiting for admin approval.';
  }

  /// Same inbox thread the website opens for a payment (`pay_<payment id>`).
  static Future<void> _notifyAdmins({
    required String paymentId,
    required String paymentNo,
    required String uid,
    required String familyName,
    required String elderId,
    required String elderName,
    required int months,
    required double amount,
    required String reference,
  }) async {
    try {
      final name = familyName.isEmpty ? 'Family' : familyName;
      final text = '$name sent ${formatPeso(amount)} for ${planLengthText(months)} '
          '(GCash ref $reference). Waiting for admin review.';
      final preview = text.length > 90 ? '${text.substring(0, 90)}…' : text;
      final thread = _db.collection('inbox_thread').doc('pay_$paymentId');
      final batch = _db.batch();
      batch.set(thread, {
        'thread_no': 'TCK-${paymentId.substring(paymentId.length - 6).toUpperCase()}',
        'type': 'care_plan',
        'subject': 'Care plan payment $paymentNo',
        'status': 'open',
        'participant_ids': [uid, 'admins'],
        'participants': {
          uid: {'name': name, 'role': 'family'},
          'admins': {'name': 'ALISTO Support', 'role': 'admin'},
        },
        'unread': {uid: 0, 'admins': 1},
        'created_by': uid,
        'elder_id': elderId,
        'elder_name': elderName,
        'related_id': paymentNo,
        'meta': <String, dynamic>{},
        'last_message_at': FieldValue.serverTimestamp(),
        'last_message_preview': preview,
        'last_sender_id': uid,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
      batch.set(thread.collection('messages').doc(), {
        'sender_id': uid,
        'sender_key': uid,
        'sender_name': name,
        'sender_role': 'system',
        'body': text,
        'is_system': true,
        'created_at': FieldValue.serverTimestamp(),
      });
      await batch.commit().timeout(_serverWait);
    } catch (_) {
      // The payment itself is already saved and shows on the Subscriptions page.
    }
  }
}
