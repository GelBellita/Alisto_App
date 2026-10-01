import 'package:cloud_firestore/cloud_firestore.dart';

/// The Pi writes a heartbeat to device/{serial}.last_seen every ~30s (see
/// alisto_main.py's heartbeat_loop()) -- treat it as stale (device likely
/// crashed or lost power) after 3x that interval, to absorb a missed
/// cycle or two without flickering to "Offline" falsely.
const int kHeartbeatStaleAfterSeconds = 90;

/// Combines the device doc's stored 'status' field with the freshness of
/// its 'last_seen' heartbeat. The Pi only ever sets 'status' to 'Online'
/// once, at pairing time -- nothing flips it back if the Pi later
/// crashes or loses power, so trusting 'status' alone would show a dead
/// device as "Online" forever. A device that was never paired ('Pending')
/// or was explicitly marked otherwise is returned as-is.
String effectiveDeviceStatus(String storedStatus, dynamic lastSeenRaw) {
  if (storedStatus != 'Online') return storedStatus;
  if (lastSeenRaw is! Timestamp) return 'Offline'; // no heartbeat ever received
  final age = DateTime.now().difference(lastSeenRaw.toDate());
  return age.inSeconds > kHeartbeatStaleAfterSeconds ? 'Offline' : 'Online';
}

class ContactModel {
  final String id;
  final String name;
  final String relation;
  final String phone;
  final String type; // 'family' or 'bhw'

  ContactModel({
    required this.id,
    required this.name,
    required this.relation,
    required this.phone,
    required this.type,
  });

  factory ContactModel.fromDoc(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ContactModel(
      id: doc.id,
      name: data['full_name'] ?? '',
      relation: data['relationship'] ?? '',
      phone: data['contact_num'] ?? '',
      type: data['contact_type'] ?? 'family',
    );
  }

  /// Two-letter initials generated from the name, e.g. "Juan Santos" -> "JS".
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

class MedicineModel {
  final String id;
  final String name;
  final String time;
  final String status; // 'Upcoming' or 'Notified'

  /// 'daily' (the original, still-default behavior: fires once a day at
  /// [time]), 'every_hours' (fires every [intervalValue] hours, anchored
  /// to [time] as the first dose of the day), or 'every_days' (fires at
  /// [time], but only on days that are an exact multiple of
  /// [intervalValue] days since [startDate] -- e.g. intervalValue=2 for
  /// "every other day"). The device (see alisto_main.py's
  /// _should_fire_now()) reads these same three fields to decide when to
  /// actually speak the reminder.
  final String scheduleType;
  final int? intervalValue;
  final String? startDate; // "YYYY-MM-DD", only set for 'every_days'

  MedicineModel({
    required this.id,
    required this.name,
    required this.time,
    required this.status,
    this.scheduleType = 'daily',
    this.intervalValue,
    this.startDate,
  });

  factory MedicineModel.fromDoc(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MedicineModel(
      id: doc.id,
      name: data['medicine_name'] ?? '',
      time: data['reminder_time'] ?? '',
      status: data['status'] ?? 'Upcoming',
      scheduleType: data['schedule_type'] ?? 'daily',
      intervalValue: data['interval_value'] as int?,
      startDate: data['start_date'] as String?,
    );
  }

  /// Short human-readable summary shown in place of a plain time, e.g.
  /// "Every 4 hrs, from 2:30 AM" or "Every 2 days at 2:30 AM" --
  /// 'daily' just shows the time itself, unchanged from before this
  /// scheduling feature existed.
  String get scheduleLabel {
    switch (scheduleType) {
      case 'every_hours':
        return 'Every ${intervalValue ?? '?'} hrs, from $time';
      case 'every_days':
        final n = intervalValue ?? 1;
        final everyLabel = n == 1 ? 'day' : '$n days';
        return 'Every $everyLabel at $time';
      default:
        return time;
    }
  }
}

/// Reads from `emergency_alert` (renamed from the old `alert` collection
/// to match the capstone paper's ERD -- see firestore_backend.py's module
/// docstring on the Pi for the full field list). The Pi only ever writes
/// trigger_type 'VOICE'/'BUTTON' emergencies here (no 'medicine'/
/// 'battery'/'system' rows were ever actually produced under the old
/// schema either), so [type] is a fixed 'emergency' rather than a field
/// read off the doc -- matches the paper's EMERGENCY_ALERT entity, which
/// has no such column.
class AlertModel {
  final String id;
  final String type;
  final String title;
  final String time;
  final List<String> lines;
  final bool acknowledged;

  AlertModel({
    required this.id,
    required this.title,
    required this.time,
    required this.lines,
    this.type = 'emergency',
    this.acknowledged = false,
  });

  factory AlertModel.fromDoc(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AlertModel(
      id: doc.id,
      title: data['title'] ?? '',
      time: _formatTriggeredAt(data['date_triggered'] as Timestamp?),
      lines: List<String>.from(data['lines'] ?? const []),
      acknowledged: data['acknowledged'] == true,
    );
  }

  static String _formatTriggeredAt(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }
}

/// A single ping from the `DEVICE_LOCATION` collection — the same
/// collection app.py reads for the web dashboard's "Last Known Location"
/// panel. Written by the Raspberry Pi/Flask server, keyed by device_id
/// (the device's serial number), not elder_id.
class LocationModel {
  final String address;
  final double? latitude;
  final double? longitude;
  final DateTime? recordedAt;

  LocationModel({
    required this.address,
    this.latitude,
    this.longitude,
    this.recordedAt,
  });

  factory LocationModel.fromDoc(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final recordedAtField = data['recorded_at'];
    return LocationModel(
      address: (data['location_address'] ?? '').toString(),
      latitude: (data['gps_lat'] as num?)?.toDouble(),
      longitude: (data['gps_long'] as num?)?.toDouble(),
      recordedAt: recordedAtField is Timestamp
          ? recordedAtField.toDate()
          : null,
    );
  }

  bool get hasCoordinates => latitude != null && longitude != null;
}