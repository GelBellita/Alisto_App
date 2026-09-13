import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_models.dart';
import 'auth_service.dart';

/// Firestore schema used by this app — matches app.py field-for-field.
///
/// user_account/{uid}
///   full_name, email, contact_number, role ("family"), created_at,
///   deleted_at (null), is_archived (0)
///   photoBase64   -> profile photo, stored inline (see note below)
///   -> Every account created through this app IS a "family" account —
///      BHW/admin only exist on the web, so there's no role picker here.
///
/// elder_profile/{elderId}
///   full_name, date_of_birth, address (single joined string), created_at,
///   deleted_at (null), is_archived (0), sex (app-only extra; Flask
///   doesn't read/write this field, so it's safe to keep for the app's
///   own display without breaking anything on the web side)
///
/// family_elder_link/{linkId}
///   family_user_id, elder_id, relationship, created_at (Flask doesn't set
///   created_at on this collection — extra field here, harmless)
///
/// device/{serial}
///   elder_id, is_registered, status, simNumber, gps, registeredAt
///   -> Devices are pre-seeded (e.g. by an admin/manufacturing step) —
///      claiming NEVER creates a new device document, only updates an
///      existing one. If the serial doesn't exist at all, registration
///      fails with "No matching Device ID found in the system."
///
/// emergency_contact/{contactId}
///   elder_id, full_name, relationship, contact_num, contact_type,
///   created_at
///
/// medication_reminder/{reminderId}
///   elder_id, medicine_name, reminder_time, status ("Upcoming" |
///   "Notified"), is_active, created_at, updated_at
///
/// alert/{alertId}
///   elder_id, type, title, time, lines (list of strings), created_at
///   -> Written by the Raspberry Pi/Flask server. created_at is REQUIRED
///      for ordering.
///
/// NOTE on photoBase64: stored inline on the user doc rather than Firebase
/// Storage, since Storage needs billing enabled. Downscaled to 512px /
/// quality 70 before encoding (~30-60 KB), well under Firestore's 1 MB
/// per-document limit.
///
/// NOTE on Firestore indexes: elder-scoped queries only send a
/// where('elder_id', ...) filter to Firestore (needs only the automatic
/// single-field index every collection already has) and sort client-side
/// in Dart — avoids requiring a hand-created composite index.
class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const int maxPhotoBytes = 700 * 1024;
  static const int maxFamilyPerDevice = 3;

  static String get _uid {
    final user = AuthService.currentUser;
    if (user == null) {
      throw StateError('No logged-in user — cannot access Firestore.');
    }
    return user.uid;
  }

  static DocumentReference<Map<String, dynamic>> get _userDoc =>
      _db.collection('user_account').doc(_uid);

  // ---------------------------------------------------------
  // ELDER RESOLUTION
  // ---------------------------------------------------------
  static String? _cachedElderId;
  static String? _cachedForUid;

  static Future<String> _getElderId() async {
    final uid = _uid;
    if (_cachedElderId != null && _cachedForUid == uid) {
      return _cachedElderId!;
    }
    final linkQuery = await _db
        .collection('family_elder_link')
        .where('family_user_id', isEqualTo: uid)
        .limit(1)
        .get();
    if (linkQuery.docs.isEmpty) {
      throw StateError(
        'No device is linked to this account yet. Please complete device '
        'registration first.',
      );
    }
    final elderId = linkQuery.docs.first.data()['elder_id'] as String;
    _cachedElderId = elderId;
    _cachedForUid = uid;
    return elderId;
  }

  /// Number of family accounts currently linked to [elderId] — mirrors
  /// the web's _family_link_count(). Since every account this app creates
  /// has role == 'family', this simplifies to a straight document count.
  static Future<int> _familyLinkCount(String elderId) async {
    final links = await _db
        .collection('family_elder_link')
        .where('elder_id', isEqualTo: elderId)
        .get();
    return links.docs.length;
  }

  static Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _elderScopedStream(
    String collectionName, {
    required String orderByField,
    bool descending = false,
    int? limit,
  }) {
    return _getElderId().asStream().asyncExpand((elderId) {
      return _db
          .collection(collectionName)
          .where('elder_id', isEqualTo: elderId)
          .snapshots()
          .map((snapshot) {
            final docs = snapshot.docs.toList();
            docs.sort((a, b) {
              final aTime = a.data()[orderByField] as Timestamp?;
              final bTime = b.data()[orderByField] as Timestamp?;
              if (aTime == null && bTime == null) return 0;
              if (aTime == null) return 1;
              if (bTime == null) return -1;
              return descending
                  ? bTime.compareTo(aTime)
                  : aTime.compareTo(bTime);
            });
            if (limit != null && docs.length > limit) {
              return docs.sublist(0, limit);
            }
            return docs;
          });
    });
  }

  // ---------------------------------------------------------
  // USER PROFILE
  // ---------------------------------------------------------
  /// Creates the account. Role is always 'family' — this app has no
  /// role picker, since BHW/admin only exist on the web.
  static Future<void> createUserProfile({
    required String uid,
    required String fullName,
    required String email,
    required String phone,
  }) {
    return _db.collection('user_account').doc(uid).set({
      'full_name': fullName,
      'email': email,
      'contact_number': phone,
      'role': 'family',
      'created_at': FieldValue.serverTimestamp(),
      'deleted_at': null,
      'is_archived': 0,
    });
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> userProfileStream() {
    return _userDoc.snapshots();
  }

  // ---------------------------------------------------------
  // PROFILE PHOTO  (unchanged — still per-account)
  // ---------------------------------------------------------
  static Future<void> saveProfilePhoto(String base64Image) {
    if (base64Image.length > maxPhotoBytes) {
      throw ArgumentError(
        'Photo is too large after encoding — pick a smaller image.',
      );
    }
    return _userDoc.set({
      'photoBase64': base64Image,
      'photoUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> removeProfilePhoto() {
    return _userDoc.set({
      'photoBase64': FieldValue.delete(),
      'photoUpdatedAt': FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  // ---------------------------------------------------------
  // DEVICE + ELDER REGISTRATION (claim a NEW device)
  // ---------------------------------------------------------
  /// Claims a pre-seeded device by serial number, matching app.py's
  /// _create_account_and_elder / auto-join logic:
  /// - The device document MUST already exist (devices are pre-seeded).
  ///   If it doesn't, throws "No matching Device ID found in the system."
  /// - If nobody has claimed it yet: creates a new elder_profile from the
  ///   elder details passed in, then marks the device registered via
  ///   .update() (never .set() — the doc already exists).
  /// - If someone already claimed it: this account JOINS that elder
  ///   instead (up to maxFamilyPerDevice family accounts per elder), no
  ///   duplicate elder_profile is created.
  /// Either way, a family_elder_link row is added.
  static Future<void> registerDevice({
    required String serial,
    required String elderFullName,
    required String elderDob,
    required String elderSex,
    required String address,
    String relationship = '',
  }) async {
    final deviceRef = _db.collection('device').doc(serial);
    final deviceDoc = await deviceRef.get();

    if (!deviceDoc.exists) {
      throw StateError(
        'No matching Device ID found in the system. Please check the QR '
        'code or serial number.',
      );
    }

    final deviceData = deviceDoc.data()!;
    String elderId;

    if (deviceData['is_registered'] == true &&
        deviceData['elder_id'] != null) {
      // Already claimed — join instead of creating a duplicate elder.
      elderId = deviceData['elder_id'] as String;

      if (await _familyLinkCount(elderId) >= maxFamilyPerDevice) {
        throw StateError(
          'This device already has the maximum of $maxFamilyPerDevice '
          'linked family members.',
        );
      }
    } else {
      final elderRef = _db.collection('elder_profile').doc();
      await elderRef.set({
        'full_name': elderFullName,
        'date_of_birth': elderDob,
        'sex': elderSex,
        'address': address,
        'created_at': FieldValue.serverTimestamp(),
        'deleted_at': null,
        'is_archived': 0,
      });
      elderId = elderRef.id;

      // .update(), not .set() — the device doc already exists (pre-seeded).
      await deviceRef.update({
        'elder_id': elderId,
        'is_registered': true,
        'registeredAt': FieldValue.serverTimestamp(),
      });
    }

    await _linkFamilyToElder(elderId, relationship);
  }

  /// Links this account to an elder/device someone else already
  /// registered — the "join" path (was: "contact" role). NEVER creates a
  /// new elder_profile: if the serial doesn't match an existing,
  /// registered device, throws so the UI can tell the user to
  /// double-check the number.
  static Future<void> linkToExistingDevice({
    required String serial,
    required String relationship,
  }) async {
    final deviceDoc = await _db.collection('device').doc(serial).get();
    final deviceData = deviceDoc.data();

    if (!deviceDoc.exists ||
        deviceData?['is_registered'] != true ||
        deviceData?['elder_id'] == null) {
      throw StateError(
        'No registered Alisto device was found with that serial number. '
        'Please double-check it with the device owner.',
      );
    }

    final elderId = deviceData!['elder_id'] as String;

    if (await _familyLinkCount(elderId) >= maxFamilyPerDevice) {
      throw StateError(
        'This device already has the maximum of $maxFamilyPerDevice '
        'linked family members.',
      );
    }

    await _linkFamilyToElder(elderId, relationship);
  }

  static Future<void> _linkFamilyToElder(
    String elderId,
    String relationship,
  ) async {
    final existingLink = await _db
        .collection('family_elder_link')
        .where('family_user_id', isEqualTo: _uid)
        .where('elder_id', isEqualTo: elderId)
        .limit(1)
        .get();

    if (existingLink.docs.isEmpty) {
      await _db.collection('family_elder_link').add({
        'family_user_id': _uid,
        'elder_id': elderId,
        'relationship': relationship,
        'created_at': FieldValue.serverTimestamp(),
      });
    }

    _cachedElderId = elderId;
    _cachedForUid = _uid;
  }

  static Future<void> updateSimNumber(String simNumber) async {
    final elderId = await _getElderId();
    final deviceQuery = await _db
        .collection('device')
        .where('elder_id', isEqualTo: elderId)
        .limit(1)
        .get();
    if (deviceQuery.docs.isEmpty) return;
    return deviceQuery.docs.first.reference.update({
      'simNumber': simNumber,
    });
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>?> deviceStream() {
    return _getElderId().asStream().asyncExpand((elderId) {
      return _db
          .collection('device')
          .where('elder_id', isEqualTo: elderId)
          .limit(1)
          .snapshots()
          .map(
            (query) => query.docs.isEmpty
                ? null
                : query.docs.first as DocumentSnapshot<Map<String, dynamic>>,
          );
    });
  }

  static Future<bool> hasDevice() async {
    final linkQuery = await _db
        .collection('family_elder_link')
        .where('family_user_id', isEqualTo: _uid)
        .limit(1)
        .get();
    return linkQuery.docs.isNotEmpty;
  }

  // ---------------------------------------------------------
  // CONTACTS — top-level 'emergency_contact', elder-scoped
  // ---------------------------------------------------------
  static Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  contactsStream() {
    return _elderScopedStream(
      'emergency_contact',
      orderByField: 'created_at',
    );
  }

  static Future<void> addContact({
    required String name,
    required String relation,
    required String phone,
    required String type,
  }) async {
    final elderId = await _getElderId();
    await _db.collection('emergency_contact').add({
      'elder_id': elderId,
      'full_name': name,
      'relationship': relation,
      'contact_num': phone,
      'contact_type': type,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteContact(String contactId) {
    return _db.collection('emergency_contact').doc(contactId).delete();
  }

  // ---------------------------------------------------------
  // MEDICINES — top-level 'medication_reminder', elder-scoped
  // ---------------------------------------------------------
  static Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  medicinesStream() {
    return _elderScopedStream(
      'medication_reminder',
      orderByField: 'created_at',
    );
  }

  static Future<void> addMedicine({
    required String name,
    required String time,
  }) async {
    final elderId = await _getElderId();
    await _db.collection('medication_reminder').add({
      'elder_id': elderId,
      'medicine_name': name,
      'reminder_time': time,
      'status': 'Upcoming',
      'is_active': true,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  /// Edits an existing reminder. Status is left alone unless passed in,
  /// since it is normally written by the device.
  static Future<void> updateMedicine({
    required String medicineId,
    required String name,
    required String time,
    String? status,
  }) {
    return _db.collection('medication_reminder').doc(medicineId).update({
      'medicine_name': name,
      'reminder_time': time,
      if (status != null) 'status': status,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteMedicine(String medicineId) {
    return _db.collection('medication_reminder').doc(medicineId).delete();
  }

  // ---------------------------------------------------------
  // ALERTS — top-level 'alert', elder-scoped
  // ---------------------------------------------------------
  static Stream<List<AlertModel>> alertsStream() {
    return _elderScopedStream(
      'alert',
      orderByField: 'created_at',
      descending: true,
    ).map((docs) => docs.map((d) => AlertModel.fromDoc(d)).toList());
  }

  static Stream<int> alertsCountStream() {
    return alertsStream().map((list) => list.length);
  }

  static Stream<AlertModel?> latestAlertStream() {
    return _elderScopedStream(
      'alert',
      orderByField: 'created_at',
      descending: true,
      limit: 1,
    ).map((docs) => docs.isEmpty ? null : AlertModel.fromDoc(docs.first));
  }
}
