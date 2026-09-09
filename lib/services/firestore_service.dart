import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_models.dart';
import 'auth_service.dart';

/// Firestore schema used by this app:
///
/// users/{uid}
///   fullName, email, phone, role ("device_owner" | "contact"), createdAt
///   photoBase64   -> profile photo, stored inline (see note below)
///   personalInfo: { age, sex, contactNumber }
///   address: { houseNo, zip, street, barangay, city }
///
/// users/{uid}/device/info
///   serial, status, simNumber, gps, registeredAt
///   -> simNumber defaults to the owner's phone number on registration
///
/// users/{uid}/contacts/{contactId}
///   name, relation, phone, type ("family" | "bhw"), createdAt
///
/// users/{uid}/medicines/{medicineId}
///   name, time, status ("Upcoming" | "Notified"), createdAt, updatedAt
///
/// users/{uid}/alerts/{alertId}
///   type, title, time, lines (list of strings), createdAt
///   -> In production this is written by the Raspberry Pi/Flask server
///      whenever the device detects an emergency, low battery, etc.
///   -> createdAt is REQUIRED: alerts are ordered by it, and Firestore
///      silently drops documents that are missing the field being ordered on.
///
/// NOTE on photoBase64: the photo is stored as a base64 string on the user
/// document rather than in Firebase Storage, because Storage needs billing
/// enabled on the project. Images are downscaled to 512px / quality 70 before
/// encoding, which lands around 30-60 KB — well under Firestore's 1 MB
/// per-document limit.
class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Rejects anything that would put the user document near Firestore's
  /// 1 MB document ceiling.
  static const int maxPhotoBytes = 700 * 1024;

  static String get _uid {
    final user = AuthService.currentUser;
    if (user == null) {
      throw StateError('No logged-in user — cannot access Firestore.');
    }
    return user.uid;
  }

  static DocumentReference<Map<String, dynamic>> get _userDoc =>
      _db.collection('users').doc(_uid);

  // ---------------------------------------------------------
  // USER PROFILE
  // ---------------------------------------------------------
  static Future<void> createUserProfile({
    required String uid,
    required String fullName,
    required String email,
    required String phone,
  }) {
    return _db.collection('users').doc(uid).set({
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'role': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> setRole(String role) {
    return _userDoc.set({'role': role}, SetOptions(merge: true));
  }

  static Future<void> savePersonalInfo({
    required String fullName,
    required String age,
    required String sex,
    required String contactNumber,
  }) {
    return _userDoc.set({
      'fullName': fullName,
      'personalInfo': {'age': age, 'sex': sex, 'contactNumber': contactNumber},
    }, SetOptions(merge: true));
  }

  static Future<void> saveAddress({
    required String houseNo,
    required String zip,
    required String street,
    required String barangay,
    required String city,
  }) {
    return _userDoc.set({
      'address': {
        'houseNo': houseNo,
        'zip': zip,
        'street': street,
        'barangay': barangay,
        'city': city,
      },
    }, SetOptions(merge: true));
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> userProfileStream() {
    return _userDoc.snapshots();
  }

  // ---------------------------------------------------------
  // PROFILE PHOTO
  // ---------------------------------------------------------
  /// Saves a downscaled, base64-encoded profile photo on the user document.
  /// Throws if the encoded image is too large for a Firestore document.
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
  // DEVICE
  // ---------------------------------------------------------
  /// Registers the device. The SIM number defaults to the owner's phone
  /// number so the Device Status card never shows a blank dash.
  static Future<void> registerDevice({required String serial}) async {
    final profile = await _userDoc.get();
    final data = profile.data();
    final personalInfo = data?['personalInfo'] as Map<String, dynamic>?;
    final phone = (personalInfo?['contactNumber'] ?? data?['phone'] ?? '')
        .toString()
        .trim();

    await _userDoc.collection('device').doc('info').set({
      'serial': serial,
      'status': 'Online',
      'simNumber': phone.isEmpty ? '—' : phone,
      'gps': 'Active',
      'registeredAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Overwrites just the SIM number — used when the owner changes their
  /// contact number after the device was already registered.
  static Future<void> updateSimNumber(String simNumber) {
    return _userDoc.collection('device').doc('info').set({
      'simNumber': simNumber,
    }, SetOptions(merge: true));
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> deviceStream() {
    return _userDoc.collection('device').doc('info').snapshots();
  }

  static Future<bool> hasDevice() async {
    final doc = await _userDoc.collection('device').doc('info').get();
    return doc.exists;
  }

  // ---------------------------------------------------------
  // CONTACTS
  // ---------------------------------------------------------
  static Stream<QuerySnapshot> contactsStream() {
    return _userDoc
        .collection('contacts')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  static Future<void> addContact({
    required String name,
    required String relation,
    required String phone,
    required String type,
  }) {
    return _userDoc.collection('contacts').add({
      'name': name,
      'relation': relation,
      'phone': phone,
      'type': type,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteContact(String contactId) {
    return _userDoc.collection('contacts').doc(contactId).delete();
  }

  // ---------------------------------------------------------
  // MEDICINES
  // ---------------------------------------------------------
  static Stream<QuerySnapshot> medicinesStream() {
    return _userDoc
        .collection('medicines')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  static Future<void> addMedicine({
    required String name,
    required String time,
  }) {
    return _userDoc.collection('medicines').add({
      'name': name,
      'time': time,
      'status': 'Upcoming',
      'createdAt': FieldValue.serverTimestamp(),
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
    return _userDoc.collection('medicines').doc(medicineId).update({
      'name': name,
      'time': time,
      if (status != null) 'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteMedicine(String medicineId) {
    return _userDoc.collection('medicines').doc(medicineId).delete();
  }

  // ---------------------------------------------------------
  // ALERTS
  // ---------------------------------------------------------
  static Stream<QuerySnapshot> alertsStream() {
    return _userDoc
        .collection('alerts')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Live count of alerts — shown on the Home screen device status card.
  static Stream<int> alertsCountStream() {
    return alertsStream().map((snapshot) => snapshot.docs.length);
  }

  /// Most recent alert, or null when there are none yet.
  /// Shown as "Last Alert" on the Home screen device status card.
  static Stream<AlertModel?> latestAlertStream() {
    return _userDoc
        .collection('alerts')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.isEmpty
              ? null
              : AlertModel.fromDoc(snapshot.docs.first),
        );
  }
}
