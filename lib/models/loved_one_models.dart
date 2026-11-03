import 'dart:convert';
import 'dart:typed_data';

// =========================================================
// LOVED ONES — shapes the web's My Loved Ones page uses.
// Built by LovedOnesService from the SAME Firestore collections the
// web reads (elder_profile, family_elder_link, device, device_location,
// medication_reminder, emergency_alert, emergency_contact).
// =========================================================

/// Relationship choices — identical to the web's <select> options.
const List<String> kRelationshipOptions = [
  'Son/Daughter',
  'Spouse',
  'Sibling',
  'Grandchild',
  'Caregiver',
  'Other',
];

/// Card status, same three buckets as the web's filter tabs.
enum LovedOneStatus { online, offline, attention }

/// One loved-one card / details screen — mirrors app.py's
/// _loved_one_snapshot() field for field.
class LovedOne {
  final String id;
  final String name;
  final String initials;
  final String? photoUrl; // "data:image/jpeg;base64,..." like the web
  final String relationship;
  final String? dateOfBirth; // "YYYY-MM-DD"
  final String? address;

  final LovedOneStatus status;
  final bool isEmergency; // badge 'emergency' (open alert)
  final String statusLabel; // Emergency / Online / Offline / No Device ...

  final String? deviceId;
  final String deviceStatus;
  final String deviceNote;
  final String? simNumber;
  final String? loadText;
  final String? loadChecked;
  final bool loadLow;
  final String accountsText;

  final String lastCheckin;
  final bool checkinOverdue;
  final String nextMedicine;
  final bool medicineOverdue;
  final String location;

  const LovedOne({
    required this.id,
    required this.name,
    required this.initials,
    required this.photoUrl,
    required this.relationship,
    required this.dateOfBirth,
    required this.address,
    required this.status,
    required this.isEmergency,
    required this.statusLabel,
    required this.deviceId,
    required this.deviceStatus,
    required this.deviceNote,
    required this.simNumber,
    required this.loadText,
    required this.loadChecked,
    required this.loadLow,
    required this.accountsText,
    required this.lastCheckin,
    required this.checkinOverdue,
    required this.nextMedicine,
    required this.medicineOverdue,
    required this.location,
  });
}

/// emergency_contact/{id} — FAMILY | BHW | OTHER, like the web.
class EmergencyContact {
  final String id;
  final String fullName;
  final String relationship;
  final String contactNum;
  final String emailAdd;
  final String contactType;

  const EmergencyContact({
    required this.id,
    required this.fullName,
    required this.relationship,
    required this.contactNum,
    required this.emailAdd,
    required this.contactType,
  });

  String get typeLabel => switch (contactType) {
        'FAMILY' => 'Family',
        'BHW' => 'BHW',
        _ => 'Other',
      };
}

/// An approved BHW assigned to the loved one's barangay.
class BhwInfo {
  final String id;
  final String fullName;
  final String contactNum;
  final String barangay;
  final String healthCenter;

  const BhwInfo({
    required this.id,
    required this.fullName,
    required this.contactNum,
    required this.barangay,
    required this.healthCenter,
  });
}

/// What /loved-ones/check-device answers.
class DeviceLookup {
  final String deviceId;
  final bool isExisting; // false -> 'new' (free device)
  final String? elderName;
  final String? elderInitials;
  final String? elderDob;
  final int familyCount;
  final int familyLimit;

  const DeviceLookup({
    required this.deviceId,
    required this.isExisting,
    this.elderName,
    this.elderInitials,
    this.elderDob,
    this.familyCount = 0,
    this.familyLimit = 0,
  });
}

String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

Uint8List? decodeDataUrl(String? dataUrl) {
  if (dataUrl == null || dataUrl.isEmpty) return null;
  final comma = dataUrl.indexOf(',');
  final raw = comma >= 0 ? dataUrl.substring(comma + 1) : dataUrl;
  try {
    return base64Decode(raw);
  } catch (_) {
    return null;
  }
}
