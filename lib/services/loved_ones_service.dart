import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../models/loved_one_models.dart';
import 'auth_service.dart';
import 'barangays.dart';
import 'firestore_service.dart';

/// Thrown with a message that is safe to show the user as-is — the same
/// wording the web's JSON routes return.
class LovedOneException implements Exception {
  final String message;
  final String? field;
  LovedOneException(this.message, {this.field});
  @override
  String toString() => message;
}

// =========================================================
// LOVED ONES SERVICE
//
// A Dart port of the "MY LOVED ONES" + "EMERGENCY CONTACTS" section of
// app.py. Every read and write here uses the same collections, field
// names, rules and messages as the web routes, so something done in the
// app shows up on the web the same way (and the other way around):
//
//   /my-loved-ones                         -> loadLovedOnes()
//   /loved-ones/check-device               -> checkDevice()
//   /loved-ones/join                       -> joinLovedOne()
//   /loved-ones/add                        -> addLovedOne()
//   /loved-ones/<id>/details               -> loadLovedOne()
//   /loved-ones/<id>/update                -> updateLovedOne()
//   /loved-ones/<id>/photo                 -> uploadPhoto()
//   /loved-ones/<id>/link-device           -> linkDevice()
//   /loved-ones/<id>/delete                -> deleteLovedOne()
//   /loved-ones/<id>/contacts (+add/update/delete) -> contacts methods
// =========================================================
//
// READ BUDGET (Firebase free tier = 50,000 reads/day):
//   - device_location: ONLY the newest ping (orderBy + limit 1). Needs the
//     composite index device_id ASC + recorded_at DESC -- the same one the
//     web's _latest_device_location() already uses.
//   - emergency_alert: ONLY open alerts (alert_status PENDING/SENT).
//   - BHWs: ONLY bhw_profile rows for the elder's barangay, cached.
//   - Family-account checks and the whole list are cached in memory, and
//     nothing reloads on a timer -- only on open, pull-to-refresh, or after
//     a change. About 10-15 reads per loved one per load.
class LovedOnesService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---- in-memory caches (per app session) ----
  static List<LovedOne>? _listCache;
  static DateTime? _listCacheAt;
  static String? _listCacheUid;
  static const Duration _listCacheTtl = Duration(seconds: 60);

  /// user_account id -> counts as an active family account. Roles almost
  /// never change, so this is only read once per account per session.
  static final Map<String, bool> _isActiveFamily = {};

  /// canonical barangay -> (BHWs, when fetched).
  static final Map<String, (List<BhwInfo>, DateTime)> _bhwCache = {};
  static const Duration _bhwCacheTtl = Duration(minutes: 30);

  /// Forget the cached list (after any add/edit/delete).
  static void invalidate() {
    _listCache = null;
    _listCacheAt = null;
  }

  // Same constants as app.py.
  static const int maxFamilyPerDevice = 5; // MAX_FAMILY_PER_DEVICE
  static const int maxContactsPerElder = 10; // MAX_CONTACTS_PER_ELDER
  static const int photoMaxBytes = 700 * 1024; // LOVED_ONE_PHOTO_MAX_BYTES
  // The Pi writes last_seen every 30 s, so 3 min = 6 missed heartbeats. The
  // web uses 10 min, but that made the app keep showing "Online" for up to
  // 10 minutes after the device lost power.
  static const Duration deviceOnlineWindow = Duration(minutes: 3);
  static const List<String> contactTypes = ['FAMILY', 'BHW', 'OTHER'];
  static const Set<String> _missedMedStatuses = {'missed', 'overdue'};

  // app.py's TEMP_LOCATION placeholder, shown until the device reports.
  static const String _tempAddress = 'Lahug, Cebu City';
  static const String _tempLastUpdated = 'Sample data (waiting for device)';

  static String get _uid {
    final user = AuthService.currentUser;
    if (user == null) throw LovedOneException('Please log in first.');
    return user.uid;
  }

  static String get _myName => AuthService.currentUser?.displayName ?? '';

  // ---------------------------------------------------------
  // SMALL HELPERS (same as app.py)
  // ---------------------------------------------------------

  /// _clean_device_id(): remove spaces, upper-case.
  static String cleanDeviceId(String? raw) =>
      (raw ?? '').replaceAll(RegExp(r'\s+'), '').toUpperCase();

  /// _clean_ph_mobile(): '0917 123 4567' / '+639171234567' -> '09171234567'.
  static String? cleanPhMobile(String? raw) {
    var digits = (raw ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('63') && digits.length == 12) {
      digits = '0${digits.substring(2)}';
    }
    if (digits.length == 11 && digits.startsWith('09')) return digits;
    return null;
  }

  /// _valid_dob(): null if OK (or blank), otherwise an error message.
  static String? validDob(String? dob) {
    if (dob == null || dob.isEmpty) return null;
    final parsed = DateTime.tryParse(dob);
    if (parsed == null) return 'Please enter a valid date of birth.';
    final born = DateTime.utc(parsed.year, parsed.month, parsed.day);
    final today = _phNow();
    if (born.isAfter(DateTime.utc(today.year, today.month, today.day))) {
      return 'Date of birth cannot be in the future.';
    }
    if (born.year < 1900) return 'Please enter a valid date of birth.';
    return null;
  }

  /// Philippine time (UTC+8), like app.py's PH_TZ — kept as a UTC-flagged
  /// DateTime shifted by 8h so date/hour math matches the web exactly.
  static DateTime _phNow() =>
      DateTime.now().toUtc().add(const Duration(hours: 8));

  static DateTime? _toPh(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toUtc().add(const Duration(hours: 8));
    }
    if (value is DateTime) {
      return value.toUtc().add(const Duration(hours: 8));
    }
    return null;
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static String _clock(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// _friendly_time(): 'Today, 10:29 AM' / 'Yesterday, 4:15 PM' /
  /// 'May 20, 2026 · 10:45 AM'.
  static String friendlyTime(DateTime? ph) {
    if (ph == null) return '—';
    final today = _phNow();
    if (_sameDay(ph, today)) return 'Today, ${_clock(ph)}';
    if (_sameDay(ph, today.subtract(const Duration(days: 1)))) {
      return 'Yesterday, ${_clock(ph)}';
    }
    final day = ph.day.toString().padLeft(2, '0');
    return '${_months[ph.month - 1]} $day, ${ph.year} · ${_clock(ph)}';
  }

  static Future<void> _logActivity(
    String elderId, {
    required String title,
    String detail = '',
    String badge = '',
    String badgeClass = '',
    String locationAddress = '',
    String? deviceId,
  }) async {
    // Same shape as app.py's _log_activity(); never breaks the action.
    try {
      await _db.collection('activity_log').add({
        'elder_id': elderId,
        'type': 'device',
        'title': title,
        'detail': detail,
        'badge': badge,
        'badge_class': badgeClass,
        'location_address': locationAddress,
        'device_id': deviceId,
        'actor_user_id': _uid,
        'ref_id': null,
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// _family_link_count(): family accounts (not deleted) linked to [elderId].
  static Future<int> familyLinkCount(String elderId) async {
    final links = await _db
        .collection('family_elder_link')
        .where('elder_id', isEqualTo: elderId)
        .get();
    var count = 0;
    for (final link in links.docs) {
      final userId = link.data()['family_user_id'] as String?;
      if (userId == null) continue;
      final cached = _isActiveFamily[userId];
      if (cached != null) {
        if (cached) count++;
        continue;
      }
      try {
        final user = await _db.collection('user_account').doc(userId).get();
        final u = user.data();
        final active =
            u != null && u['role'] == 'family' && u['deleted_at'] == null;
        _isActiveFamily[userId] = active;
        if (active) count++;
      } catch (_) {
        // Rules may block reading other accounts -- count the link anyway.
        _isActiveFamily[userId] = true;
        count++;
      }
    }
    return count;
  }

  /// _get_elder_if_linked(): the elder doc + MY link, or throws.
  static Future<
    (
      DocumentSnapshot<Map<String, dynamic>>,
      QueryDocumentSnapshot<Map<String, dynamic>>,
    )
  >
  _elderIfLinked(String elderId) async {
    final links = await _db
        .collection('family_elder_link')
        .where('family_user_id', isEqualTo: _uid)
        .where('elder_id', isEqualTo: elderId)
        .limit(1)
        .get();
    if (links.docs.isEmpty) throw LovedOneException('Loved one not found.');
    final elder = await _db.collection('elder_profile').doc(elderId).get();
    if (!elder.exists || elder.data()?['deleted_at'] != null) {
      throw LovedOneException('Loved one not found.');
    }
    return (elder, links.docs.first);
  }

  // ---------------------------------------------------------
  // SNAPSHOT PIECES
  // ---------------------------------------------------------
  static Future<(String?, Map<String, dynamic>)> _deviceForElder(
    String elderId,
  ) async {
    final q = await _db
        .collection('device')
        .where('elder_id', isEqualTo: elderId)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return (null, <String, dynamic>{});
    return (q.docs.first.id, q.docs.first.data());
  }

  static Future<Map<String, dynamic>?> _latestLocation(String? serial) async {
    if (serial == null) return null;
    try {
      // 1 read, no matter how many pings the device has written.
      final q = await _db
          .collection('device_location')
          .where('device_id', isEqualTo: serial)
          .orderBy('recorded_at', descending: true)
          .limit(1)
          .get();
      return q.docs.isEmpty ? null : q.docs.first.data();
    } catch (e) {
      // Usually the missing composite index. The message contains a link
      // that creates it in the Firebase console. Deliberately NO fallback
      // that reads every ping -- that is what used to eat the read quota.
      debugPrint('LovedOnesService: latest location query failed: $e');
      return null;
    }
  }

  static DateTime? _deviceLastSeen(
    Map<String, dynamic> device,
    Map<String, dynamic>? loc,
  ) {
    final times = [
      _toPh(loc?['recorded_at']),
      _toPh(device['last_seen']),
    ].whereType<DateTime>().toList();
    if (times.isEmpty) return null;
    times.sort();
    return times.last;
  }

  /// _device_summary(): (status, statusClass, note).
  static (String, String, String) _deviceSummary(
    String? serial,
    Map<String, dynamic> device,
    Map<String, dynamic>? loc,
  ) {
    if (serial == null) {
      return (
        'No Device',
        'none',
        'No ALISTO device is linked to this loved one yet.',
      );
    }
    if (device['is_registered'] != true) {
      return (
        'Not Registered',
        'attention',
        'Device $serial is not registered yet.',
      );
    }
    final lastSeen = _deviceLastSeen(device, loc);
    final bool online;
    if (lastSeen != null) {
      online = _phNow().difference(lastSeen) < deviceOnlineWindow;
    } else {
      online = (device['status'] ?? '').toString().toLowerCase() == 'online';
    }
    final battery = device['battery_level'];
    final batteryText = battery is num ? ' Battery $battery%.' : '';
    if (online) {
      return (
        'Online',
        'online',
        'Device is connected and working properly.$batteryText',
      );
    }
    final note = lastSeen != null
        ? 'Last check-in: ${friendlyTime(lastSeen)}.'
        : 'No check-in received from the device yet.';
    return ('Offline', 'offline', '$note$batteryText');
  }

  /// _reminder_clock(): (hour, minute) of the start time, or null.
  static (int, int)? _reminderClock(String? reminderTime) {
    final text = (reminderTime ?? '').trim().toUpperCase();
    final tokens = RegExp(
      r'(\d{1,2})(?:\s*:\s*(\d{2}))?\s*(AM|PM|A\.M\.|P\.M\.)?',
    ).allMatches(text).toList();
    if (tokens.isEmpty) return null;
    var hour = int.parse(tokens[0].group(1)!);
    final minute = int.parse(tokens[0].group(2) ?? '0');
    var meridiem = (tokens[0].group(3) ?? '');
    meridiem = meridiem.isEmpty ? '' : meridiem[0];
    if (meridiem.isEmpty) {
      final later = tokens
          .skip(1)
          .where((t) => (t.group(3) ?? '').isNotEmpty)
          .toList();
      if (later.isNotEmpty) {
        meridiem = later.first.group(3)![0];
        final endHour = int.parse(later.first.group(1)!);
        if (meridiem == 'P' && hour != 12 && endHour != 12 && hour > endHour) {
          meridiem = 'A';
        }
      }
    }
    if (meridiem.isNotEmpty) {
      if (hour < 1 || hour > 12) return null;
      if (meridiem == 'P' && hour < 12) hour += 12;
      if (meridiem == 'A' && hour == 12) hour = 0;
    }
    if (hour > 23 || minute > 59) return null;
    return (hour, minute);
  }

  /// _next_occurrence(): next due time for one reminder, or null.
  static DateTime? _nextOccurrence(Map<String, dynamic> med, DateTime now) {
    final clock = _reminderClock(
      (med['reminder_time'] ?? med['time'] ?? '').toString(),
    );
    if (clock == null) return null;
    final (hour, minute) = clock;
    final type = (med['schedule_type'] ?? 'daily').toString();
    final today = DateTime.utc(now.year, now.month, now.day);

    if (type == 'every_hours') {
      final interval = int.tryParse('${med['interval_value'] ?? 0}') ?? 0;
      if (interval <= 0) return null;
      for (final offset in [0, 1]) {
        final dayStart = today.add(Duration(days: offset));
        var slot = dayStart.add(Duration(minutes: hour * 60 + minute));
        while (slot.isBefore(dayStart.add(const Duration(days: 1)))) {
          if (slot.isAfter(now)) return slot;
          slot = slot.add(Duration(hours: interval));
        }
      }
      return null;
    }

    if (type == 'every_days') {
      var interval = int.tryParse('${med['interval_value'] ?? 1}') ?? 1;
      if (interval < 1) interval = 1;
      final start = DateTime.tryParse('${med['start_date'] ?? ''}');
      final startDate = start == null
          ? today
          : DateTime.utc(start.year, start.month, start.day);
      for (var offset = 0; offset <= interval * 8; offset++) {
        final day = today.add(Duration(days: offset));
        final since = day.difference(startDate).inDays;
        if (since < 0 || since % interval != 0) continue;
        final due = day.add(Duration(hours: hour, minutes: minute));
        if (due.isAfter(now)) return due;
      }
      return null;
    }

    for (var offset = 0; offset < 8; offset++) {
      final due = today.add(
        Duration(days: offset, hours: hour, minutes: minute),
      );
      if (due.isAfter(now)) return due;
    }
    return null;
  }

  /// (_next_medicine() text, _has_missed_medicine()) in one read.
  static Future<(String, bool)> _medicineInfo(String elderId) async {
    try {
      final docs = await _db
          .collection('medication_reminder')
          .where('elder_id', isEqualTo: elderId)
          .get();
      final now = _phNow();
      DateTime? bestDue;
      Map<String, dynamic>? bestMed;
      var missed = false;
      for (final d in docs.docs) {
        final med = d.data();
        if (med['deleted_at'] != null || med['is_active'] == false) continue;
        if (_missedMedStatuses.contains(
          (med['status'] ?? '').toString().toLowerCase(),
        )) {
          missed = true;
        }
        final due = _nextOccurrence(med, now);
        if (due != null && (bestDue == null || due.isBefore(bestDue))) {
          bestDue = due;
          bestMed = med;
        }
      }
      if (bestDue == null || bestMed == null) {
        return ('No reminders set', missed);
      }
      final String dayLabel;
      if (_sameDay(bestDue, now)) {
        dayLabel = 'Today';
      } else if (_sameDay(bestDue, now.add(const Duration(days: 1)))) {
        dayLabel = 'Tomorrow';
      } else {
        dayLabel = _weekdays[bestDue.weekday - 1];
      }
      var name = (bestMed['medicine_name'] ?? bestMed['name'] ?? '')
          .toString()
          .trim();
      if (name.isEmpty) name = 'Unnamed medicine';
      if ((bestMed['dosage'] ?? '').toString().isNotEmpty) {
        name += ' · ${bestMed['dosage']}';
      }
      return ('$name — ${_clock(bestDue)} $dayLabel', missed);
    } catch (_) {
      return ('No reminders set', false);
    }
  }

  /// Any still-open (not acknowledged / resolved / cancelled) alert —
  /// same rule as ac.row_status() == 'active'.
  static Future<bool> _hasOpenAlert(String elderId) async {
    try {
      // Only still-open alerts are read, not the elder's whole history.
      // (== plus whereIn needs no composite index.)
      final q = await _db
          .collection('emergency_alert')
          .where('elder_id', isEqualTo: elderId)
          .where('alert_status', whereIn: ['PENDING', 'SENT'])
          .get();
      return q.docs.any((d) {
        final a = d.data();
        return a['deleted_at'] == null && a['acknowledged'] != true;
      });
    } catch (_) {
      return false;
    }
  }

  static String _peso(num amount) {
    final fixed = amount.toStringAsFixed(2);
    final parts = fixed.split('.');
    final whole = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]},',
    );
    return '₱$whole.${parts[1]}';
  }

  /// _loved_one_snapshot()
  static Future<LovedOne> _snapshot(
    String elderId,
    Map<String, dynamic> elder,
    Map<String, dynamic> link,
  ) async {
    final name = (elder['full_name'] ?? '').toString().trim().isEmpty
        ? 'Unnamed'
        : elder['full_name'].toString();

    final (serial, device) = await _deviceForElder(elderId);
    final results = await Future.wait([
      _latestLocation(serial),
      _medicineInfo(elderId),
      _hasOpenAlert(elderId),
      familyLinkCount(elderId),
    ]);
    final loc = results[0] as Map<String, dynamic>?;
    final (nextMedicine, missed) = results[1] as (String, bool);
    final hasOpenAlert = results[2] as bool;
    final linkCount = results[3] as int;

    final (devStatus, devClass, devNote) = _deviceSummary(serial, device, loc);
    final lastSeen = _deviceLastSeen(device, loc);

    LovedOneStatus status;
    String label;
    if (hasOpenAlert) {
      status = LovedOneStatus.attention;
      label = 'Emergency';
    } else if (devClass == 'online') {
      status = LovedOneStatus.online;
      label = 'Online';
    } else if (devClass == 'offline') {
      status = LovedOneStatus.offline;
      label = 'Offline';
    } else {
      status = LovedOneStatus.attention;
      label = devStatus;
    }

    var location = _tempAddress;
    if (loc != null &&
        ((loc['location_address'] ?? '').toString().isNotEmpty ||
            loc['gps_lat'] is num)) {
      final addr = (loc['location_address'] ?? '').toString();
      if (addr.isNotEmpty) {
        location = addr;
      } else if (loc['gps_long'] is num) {
        location =
            '${(loc['gps_lat'] as num).toStringAsFixed(5)}, '
            '${(loc['gps_long'] as num).toStringAsFixed(5)}';
      } else {
        location = 'Address not reported';
      }
    }

    // device_info.load_info()
    String? loadText, loadChecked;
    var loadLow = false;
    final amount = device['loadBalance'];
    if (amount != null ||
        (device['loadText'] ?? '').toString().isNotEmpty ||
        device['loadCheckedAt'] != null) {
      if (amount is num) {
        loadText = _peso(amount);
        loadLow = amount < 10;
      } else {
        loadText = 'Could not read';
      }
      loadChecked = device['loadCheckedAt'] != null
          ? friendlyTime(_toPh(device['loadCheckedAt']))
          : '—';
    }

    final sim = (device['simNumber'] ?? device['sim_number'])?.toString();

    return LovedOne(
      id: elderId,
      name: name,
      initials: initialsOf(name),
      photoUrl: (elder['photo_url'] as String?)?.isNotEmpty == true
          ? elder['photo_url'] as String
          : null,
      relationship: (link['relationship'] ?? '').toString().isEmpty
          ? 'Family'
          : link['relationship'].toString(),
      dateOfBirth: elder['date_of_birth'] as String?,
      address: elder['address']?.toString(),
      status: status,
      isEmergency: hasOpenAlert,
      statusLabel: label,
      deviceId: serial,
      deviceStatus: devStatus,
      deviceNote: devNote,
      simNumber: (sim == null || sim.isEmpty) ? null : sim,
      loadText: loadText,
      loadChecked: loadChecked,
      loadLow: loadLow,
      accountsText: '$linkCount account${linkCount == 1 ? '' : 's'}',
      lastCheckin: lastSeen != null ? friendlyTime(lastSeen) : _tempLastUpdated,
      checkinOverdue: serial != null && devClass != 'online',
      nextMedicine: nextMedicine,
      medicineOverdue: missed,
      location: location,
    );
  }

  // ---------------------------------------------------------
  // LIST  (/my-loved-ones)
  // ---------------------------------------------------------
  /// Live list: re-builds whenever this account's links change. Pull to
  /// refresh (or the screen's timer) picks up device/alert changes.
  static Stream<List<LovedOne>> lovedOnesStream() {
    return _db
        .collection('family_elder_link')
        .where('family_user_id', isEqualTo: _uid)
        .snapshots()
        .asyncMap((_) => loadLovedOnes(force: true));
  }

  /// Returns the cached list if it is less than a minute old, unless
  /// [force] (pull-to-refresh, or a link was added/removed).
  static Future<List<LovedOne>> loadLovedOnes({bool force = false}) async {
    final uid = _uid;
    final cachedAt = _listCacheAt;
    if (!force &&
        _listCache != null &&
        _listCacheUid == uid &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _listCacheTtl) {
      return _listCache!;
    }
    final links = await _db
        .collection('family_elder_link')
        .where('family_user_id', isEqualTo: _uid)
        .get();

    final linkByElder = <String, Map<String, dynamic>>{};
    for (final l in links.docs) {
      final elderId = l.data()['elder_id'] as String?;
      if (elderId == null || linkByElder.containsKey(elderId)) continue;
      linkByElder[elderId] = l.data();
    }

    final futures = linkByElder.entries.map((e) async {
      final doc = await _db.collection('elder_profile').doc(e.key).get();
      final data = doc.data();
      if (!doc.exists || data == null || data['deleted_at'] != null) {
        return null;
      }
      return _snapshot(e.key, data, e.value);
    });
    final lovedOnes = (await Future.wait(futures))
        .whereType<LovedOne>()
        .toList();

    // Emergencies first, then everyone else by name (same as the web).
    lovedOnes.sort((a, b) {
      if (a.isEmergency != b.isEmergency) return a.isEmergency ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    _listCache = lovedOnes;
    _listCacheAt = DateTime.now();
    _listCacheUid = uid;
    return lovedOnes;
  }

  /// /loved-ones/<id>/details
  static Future<LovedOne> loadLovedOne(String elderId) async {
    final (elder, link) = await _elderIfLinked(elderId);
    return _snapshot(elderId, elder.data() ?? {}, link.data());
  }

  // ---------------------------------------------------------
  // ADD A LOVED ONE — device first
  // ---------------------------------------------------------
  /// /loved-ones/check-device
  static Future<DeviceLookup> checkDevice(String raw) async {
    final serial = cleanDeviceId(raw);
    if (serial.isEmpty) throw LovedOneException('Enter the Device ID.');

    final doc = await _db.collection('device').doc(serial).get();
    if (!doc.exists) {
      throw LovedOneException(
        'No matching Device ID found. Check the sticker or scan the QR again.',
      );
    }
    final device = doc.data() ?? {};
    if (device['is_registered'] != true) {
      return DeviceLookup(deviceId: serial, isExisting: false);
    }

    final elderId = device['elder_id'] as String?;
    final elderDoc = elderId == null
        ? null
        : await _db.collection('elder_profile').doc(elderId).get();
    final elder = elderDoc?.data() ?? {};
    if (elderId == null || elder.isEmpty || elder['deleted_at'] != null) {
      throw LovedOneException(
        "This device can't be linked right now. Please contact ALISTO Support.",
      );
    }

    final already = await _db
        .collection('family_elder_link')
        .where('family_user_id', isEqualTo: _uid)
        .where('elder_id', isEqualTo: elderId)
        .limit(1)
        .get();
    final elderName = (elder['full_name'] ?? '').toString();
    if (already.docs.isNotEmpty) {
      throw LovedOneException(
        '${elderName.isEmpty ? 'This loved one' : elderName} is already in your list.',
      );
    }

    final count = await familyLinkCount(elderId);
    if (count >= maxFamilyPerDevice) {
      throw LovedOneException(
        'This device already has the maximum of $maxFamilyPerDevice family members.',
      );
    }

    final name = elderName.isEmpty ? 'Unnamed' : elderName;
    return DeviceLookup(
      deviceId: serial,
      isExisting: true,
      elderName: name,
      elderInitials: initialsOf(name),
      elderDob: (elder['date_of_birth'] ?? '').toString(),
      familyCount: count,
      familyLimit: maxFamilyPerDevice,
    );
  }

  static String _relationship(String relationship, String other) {
    final rel = relationship.trim();
    return rel == 'Other' ? other.trim() : rel;
  }

  /// /loved-ones/join — link this account to the elder already using the
  /// device. Returns the success message.
  static Future<String> joinLovedOne({
    required String deviceId,
    required String relationship,
    String relationshipOther = '',
  }) async {
    final serial = cleanDeviceId(deviceId);
    final rel = _relationship(relationship, relationshipOther);
    if (rel.isEmpty) {
      throw LovedOneException(
        'Choose how you are related to them.',
        field: 'relationship',
      );
    }

    final doc = serial.isEmpty
        ? null
        : await _db.collection('device').doc(serial).get();
    final device = doc?.data() ?? {};
    final elderId = device['is_registered'] == true
        ? device['elder_id'] as String?
        : null;
    final elderDoc = elderId == null
        ? null
        : await _db.collection('elder_profile').doc(elderId).get();
    if (elderId == null ||
        elderDoc == null ||
        !elderDoc.exists ||
        elderDoc.data()?['deleted_at'] != null) {
      throw LovedOneException(
        'This device is no longer linked to anyone. Check it again.',
      );
    }

    final already = await _db
        .collection('family_elder_link')
        .where('family_user_id', isEqualTo: _uid)
        .where('elder_id', isEqualTo: elderId)
        .limit(1)
        .get();
    if (already.docs.isNotEmpty) {
      throw LovedOneException('This loved one is already in your list.');
    }
    if (await familyLinkCount(elderId) >= maxFamilyPerDevice) {
      throw LovedOneException(
        'This device already has the maximum of $maxFamilyPerDevice family members.',
      );
    }

    final name = (elderDoc.data()?['full_name'] ?? 'Loved one').toString();
    await _db.collection('family_elder_link').add({
      'family_user_id': _uid,
      'elder_id': elderId,
      'relationship': rel.length > 60 ? rel.substring(0, 60) : rel,
      'created_at': FieldValue.serverTimestamp(),
    });
    await _logActivity(
      elderId,
      title:
          '${_myName.isEmpty ? 'A family member' : _myName} '
          "joined $name's ALISTO",
      detail: 'Linked through device $serial',
      badge: 'Linked',
      badgeClass: 'success',
      deviceId: serial,
    );
    FirestoreService.clearElderCache();
    invalidate();
    return '$name has been added to your loved ones.';
  }

  /// _attach_device(): mark a device as registered to this elder.
  static Future<void> _attachDevice(
    String serial,
    Map<String, dynamic> device,
    String elderId,
  ) {
    return _db.collection('device').doc(serial).set({
      'elder_id': elderId,
      'is_registered': true,
      'registered_at': FieldValue.serverTimestamp(),
      'registered_by': _uid,
      'serial_number': serial,
      'gps': device['gps'] ?? 'Inactive',
      'sim_number': device['sim_number'],
      'status': device['status'] ?? 'Offline',
    }, SetOptions(merge: true));
  }

  /// /loved-ones/add — new elder (with a free device, or no device yet).
  static Future<String> addLovedOne({
    required String fullName,
    required String relationship,
    String relationshipOther = '',
    String dateOfBirth = '',
    String occupation = '',
    String houseNo = '',
    String street = '',
    required String barangay,
    String city = '',
    String province = '',
    String zipCode = '',
    String deviceId = '',
  }) async {
    final name = fullName.trim();
    final serial = cleanDeviceId(deviceId);
    final brgy = canonicalBarangay(barangay.trim());
    if (brgy == null) {
      throw LovedOneException(
        'Select the barangay from the list.',
        field: 'barangay',
      );
    }
    if (name.isEmpty) {
      throw LovedOneException(
        'Enter the full name of your loved one.',
        field: 'full_name',
      );
    }
    if (relationship.trim().isEmpty) {
      throw LovedOneException(
        'Choose how you are related to them.',
        field: 'relationship',
      );
    }
    if (relationship.trim() == 'Other' && relationshipOther.trim().isEmpty) {
      throw LovedOneException(
        'Please specify your relationship.',
        field: 'relationship_other',
      );
    }
    final rel = _relationship(relationship, relationshipOther);
    final dobError = validDob(dateOfBirth.trim());
    if (dobError != null) throw LovedOneException(dobError, field: 'dob');

    final occ = occupation.trim();
    final address = [
      houseNo.trim(),
      street.trim(),
      brgy,
      city.trim(),
      province.trim(),
      zipCode.trim(),
    ].where((p) => p.isNotEmpty).join(', ');

    Map<String, dynamic>? deviceData;
    if (serial.isNotEmpty) {
      final deviceDoc = await _db.collection('device').doc(serial).get();
      if (!deviceDoc.exists) {
        throw LovedOneException(
          'No matching Device ID found in the system.',
          field: 'device_id',
        );
      }
      deviceData = deviceDoc.data() ?? {};
      if (deviceData['is_registered'] == true) {
        throw LovedOneException(
          'This Device ID is already linked to another elder. '
          'Leave it blank if you just want to register the person for now.',
          field: 'device_id',
        );
      }
    }

    final elderRef = _db.collection('elder_profile').doc();
    await elderRef.set({
      'full_name': name,
      'date_of_birth': dateOfBirth.trim().isEmpty ? null : dateOfBirth.trim(),
      'address': address,
      'occupation': occ.isEmpty
          ? null
          : (occ.length > 80 ? occ.substring(0, 80) : occ),
      'photo_url': null,
      'created_at': FieldValue.serverTimestamp(),
      'created_by': _uid,
      'deleted_at': null,
      'is_archived': 0,
    });
    final elderId = elderRef.id;

    await _db.collection('family_elder_link').add({
      'family_user_id': _uid,
      'elder_id': elderId,
      'relationship': rel,
      'created_at': FieldValue.serverTimestamp(),
    });

    if (serial.isNotEmpty) {
      await _attachDevice(serial, deviceData!, elderId);
    }

    await _logActivity(
      elderId,
      title: '$name was added to the account',
      detail: serial.isNotEmpty
          ? 'Device $serial linked'
          : 'No device linked yet',
      badge: serial.isNotEmpty ? 'Linked' : 'Pending',
      badgeClass: serial.isNotEmpty ? 'success' : 'warning',
      locationAddress: address,
      deviceId: serial.isEmpty ? null : serial,
    );
    FirestoreService.clearElderCache();
    invalidate();
    return '$name has been added to your loved ones.';
  }

  // ---------------------------------------------------------
  // DETAILS ACTIONS
  // ---------------------------------------------------------
  /// /loved-ones/<id>/update
  static Future<String> updateLovedOne({
    required String elderId,
    required String fullName,
    required String relationship,
    required String dateOfBirth,
    required String address,
  }) async {
    await _elderIfLinked(elderId);
    final name = fullName.trim();
    final rel = relationship.trim();
    final dob = dateOfBirth.trim();
    final addr = address.trim();
    if (name.isEmpty) throw LovedOneException('Full name cannot be empty.');
    if (rel.isEmpty) throw LovedOneException('Please choose a relationship.');
    final dobError = validDob(dob);
    if (dobError != null) throw LovedOneException(dobError);

    await _db.collection('elder_profile').doc(elderId).update({
      'full_name': name,
      'date_of_birth': dob.isEmpty ? null : dob,
      'address': addr,
      'updated_at': FieldValue.serverTimestamp(),
    });
    final links = await _db
        .collection('family_elder_link')
        .where('family_user_id', isEqualTo: _uid)
        .where('elder_id', isEqualTo: elderId)
        .limit(1)
        .get();
    if (links.docs.isNotEmpty) {
      await links.docs.first.reference.update({'relationship': rel});
    }
    await _logActivity(
      elderId,
      title: '$name profile updated',
      badge: 'Updated',
      badgeClass: 'warning',
      locationAddress: addr,
    );
    invalidate();
    return 'Changes saved.';
  }

  /// /loved-ones/<id>/photo — stored as a data URL in elder_profile.photo_url
  /// (not Firebase Storage), exactly like the web, so it shows everywhere.
  static Future<String> uploadPhoto(
    String elderId,
    Uint8List bytes,
    String mime,
  ) async {
    await _elderIfLinked(elderId);
    const allowed = {'image/jpeg', 'image/png', 'image/webp'};
    if (!allowed.contains(mime)) {
      throw LovedOneException('Photo must be a JPG, PNG, or WEBP image.');
    }
    final encoded = base64Encode(bytes);
    if (encoded.length > photoMaxBytes) {
      throw LovedOneException(
        'That photo is too large. Please choose a smaller one.',
      );
    }
    final photoUrl = 'data:$mime;base64,$encoded';
    await _db.collection('elder_profile').doc(elderId).update({
      'photo_url': photoUrl,
      'photo_updated_at': FieldValue.serverTimestamp(),
    });
    invalidate();
    return photoUrl;
  }

  /// /loved-ones/<id>/link-device — for a loved one added without one.
  static Future<String> linkDevice(String elderId, String raw) async {
    final (elder, _) = await _elderIfLinked(elderId);
    final serial = cleanDeviceId(raw);
    if (serial.isEmpty) throw LovedOneException('Enter the Device ID.');

    final (existing, _) = await _deviceForElder(elderId);
    if (existing != null) {
      throw LovedOneException('This loved one already has device $existing.');
    }
    final deviceDoc = await _db.collection('device').doc(serial).get();
    if (!deviceDoc.exists) {
      throw LovedOneException('No matching Device ID found in the system.');
    }
    final deviceData = deviceDoc.data() ?? {};
    if (deviceData['is_registered'] == true) {
      throw LovedOneException(
        'This Device ID is already linked to another elder.',
      );
    }
    await _attachDevice(serial, deviceData, elderId);
    final name = (elder.data()?['full_name'] ?? 'Loved one').toString();
    await _logActivity(
      elderId,
      title: 'Device linked to $name',
      detail: 'Device $serial linked',
      badge: 'Linked',
      badgeClass: 'success',
      deviceId: serial,
    );
    FirestoreService.clearElderCache();
    invalidate();
    return 'Device $serial is now linked.';
  }

  /// /loved-ones/<id>/delete — removes this loved one from MY account only.
  /// The profile is soft-deleted and the device freed only when nobody
  /// else is linked.
  static Future<String> deleteLovedOne(String elderId) async {
    final (elder, _) = await _elderIfLinked(elderId);
    final name = (elder.data()?['full_name'] ?? 'Loved one').toString();

    final allLinks = await _db
        .collection('family_elder_link')
        .where('elder_id', isEqualTo: elderId)
        .get();
    final mine = allLinks.docs
        .where((l) => l.data()['family_user_id'] == _uid)
        .toList();
    final mineIds = mine.map((l) => l.id).toSet();
    final others = allLinks.docs.where((l) => !mineIds.contains(l.id)).toList();

    for (final link in mine) {
      await link.reference.delete();
    }
    FirestoreService.clearElderCache();
    invalidate();

    if (others.isNotEmpty) {
      await _logActivity(
        elderId,
        title: 'A family member was removed from $name',
        badge: 'Removed',
        badgeClass: 'warning',
      );
      return '$name was removed from your account. '
          'Other linked family members still have access.';
    }

    await _db.collection('elder_profile').doc(elderId).update({
      'deleted_at': FieldValue.serverTimestamp(),
      'deleted_by': _uid,
    });
    final devices = await _db
        .collection('device')
        .where('elder_id', isEqualTo: elderId)
        .get();
    for (final d in devices.docs) {
      await d.reference.update({
        'elder_id': null,
        'is_registered': false,
        'registered_at': null,
        'previous_elder_id': elderId,
        'unregistered_at': FieldValue.serverTimestamp(),
        'unregistered_by': _uid,
      });
    }
    await _logActivity(
      elderId,
      title: '$name was deleted',
      detail: 'Device unlinked',
      badge: 'Deleted',
      badgeClass: 'danger',
    );
    return '$name was deleted.';
  }

  // ---------------------------------------------------------
  // EMERGENCY CONTACTS  (emergency_contact, ERD: EMERGENCY_CONTACT)
  // ---------------------------------------------------------
  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _activeContactDocs(String elderId) async {
    final q = await _db
        .collection('emergency_contact')
        .where('elder_id', isEqualTo: elderId)
        .get();
    final rows = q.docs.where((d) {
      final c = d.data();
      return c['deleted_at'] == null &&
          !(c['is_archived'] == true || c['is_archived'] == 1) &&
          c['status'] != 'INACTIVE';
    }).toList();
    rows.sort(
      (a, b) => (a.data()['full_name'] ?? '')
          .toString()
          .toLowerCase()
          .compareTo((b.data()['full_name'] ?? '').toString().toLowerCase()),
    );
    return rows;
  }

  static EmergencyContact _contactView(
    QueryDocumentSnapshot<Map<String, dynamic>> d,
  ) {
    final c = d.data();
    var type = (c['contact_type'] ?? 'OTHER').toString().toUpperCase();
    if (!contactTypes.contains(type)) type = 'OTHER';
    return EmergencyContact(
      id: d.id,
      fullName: (c['full_name'] ?? '').toString(),
      relationship: (c['relationship'] ?? '').toString(),
      contactNum: (c['contact_num'] ?? '').toString(),
      emailAdd: (c['email_add'] ?? '').toString(),
      contactType: type,
    );
  }

  /// /loved-ones/<id>/contacts — (contacts, BHWs for the elder's barangay).
  static Future<(List<EmergencyContact>, List<BhwInfo>)> loadContacts(
    String elderId,
  ) async {
    final (elder, _) = await _elderIfLinked(elderId);
    final contacts = (await _activeContactDocs(elderId))
        .map(_contactView)
        .toList();
    final bhws = await _bhwsForAddress(elder.data()?['address']);
    return (contacts, bhws);
  }

  /// _bhws_for_address(): approved BHWs assigned to this address's barangay.
  static Future<List<BhwInfo>> _bhwsForAddress(dynamic address) async {
    // The elder's barangay, in the web dropdown's spelling.
    String? barangay;
    for (final part in addressParts(address)) {
      barangay = canonicalBarangay(part);
      if (barangay != null) break;
    }
    if (barangay == null) return const [];

    final cached = _bhwCache[barangay];
    if (cached != null && DateTime.now().difference(cached.$2) < _bhwCacheTtl) {
      return cached.$1;
    }
    try {
      // Only this barangay's BHW profiles, then just those accounts --
      // instead of every bhw_profile and every BHW account.
      final profiles = await _db
          .collection('bhw_profile')
          .where('barangay_assigned', isEqualTo: barangay)
          .get();
      final rows = <BhwInfo>[];
      for (final doc in profiles.docs) {
        final p = doc.data();
        final userId = p['user_id'] as String?;
        if (userId == null) continue;
        final user = await _db.collection('user_account').doc(userId).get();
        final u = user.data();
        if (u == null ||
            u['role'] != 'bhw' ||
            u['deleted_at'] != null ||
            (u['is_archived'] == true || u['is_archived'] == 1) ||
            u['approval_status'] != 'approved') {
          continue;
        }
        rows.add(
          BhwInfo(
            id: userId,
            fullName: (u['full_name'] ?? 'BHW').toString(),
            contactNum: (u['contact_number'] ?? '').toString(),
            barangay: barangay,
            healthCenter: (p['health_center'] ?? '').toString(),
          ),
        );
      }
      _bhwCache[barangay] = (rows, DateTime.now());
      return rows;
    } catch (_) {
      // Firestore rules may not let a family account read BHW accounts.
      return const [];
    }
  }

  /// _contact_form(): validated fields, or throws.
  static Map<String, dynamic> _contactForm({
    required String fullName,
    required String relationship,
    required String contactNum,
    required String emailAdd,
    required String contactType,
  }) {
    var name = fullName.trim();
    if (name.length > 100) name = name.substring(0, 100);
    var rel = relationship.trim();
    if (rel.length > 60) rel = rel.substring(0, 60);
    final number = cleanPhMobile(contactNum);
    var email = emailAdd.trim();
    if (email.length > 120) email = email.substring(0, 120);
    var type = contactType.toUpperCase();

    if (name.isEmpty) throw LovedOneException("Enter the contact's full name.");
    if (number == null) {
      throw LovedOneException('Enter a valid mobile number, like 09171234567.');
    }
    if (email.isNotEmpty &&
        (!email.contains('@') || !email.split('@').last.contains('.'))) {
      throw LovedOneException(
        'Enter a valid email address, or leave it blank.',
      );
    }
    if (!contactTypes.contains(type)) type = 'OTHER';
    return {
      'full_name': name,
      'relationship': rel,
      'contact_num': number,
      'email_add': email,
      'contact_type': type,
    };
  }

  static Future<String> addContact({
    required String elderId,
    required String fullName,
    required String relationship,
    required String contactNum,
    String emailAdd = '',
    String contactType = 'OTHER',
  }) async {
    await _elderIfLinked(elderId);
    final fields = _contactForm(
      fullName: fullName,
      relationship: relationship,
      contactNum: contactNum,
      emailAdd: emailAdd,
      contactType: contactType,
    );
    final existing = await _activeContactDocs(elderId);
    if (existing.length >= maxContactsPerElder) {
      throw LovedOneException(
        'You can add up to $maxContactsPerElder contacts.',
      );
    }
    if (existing.any((d) => d.data()['contact_num'] == fields['contact_num'])) {
      throw LovedOneException('That number is already a contact.');
    }
    await _db.collection('emergency_contact').add({
      ...fields,
      'elder_id': elderId,
      'status': 'ACTIVE',
      'created_by': _uid,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      'deleted_at': null,
      'is_archived': false,
    });
    return 'Contact added.';
  }

  static Future<DocumentReference<Map<String, dynamic>>> _contactOfElder(
    String elderId,
    String contactId,
  ) async {
    final ref = _db.collection('emergency_contact').doc(contactId);
    final doc = await ref.get();
    final c = doc.data() ?? {};
    if (!doc.exists || c['elder_id'] != elderId || c['deleted_at'] != null) {
      throw LovedOneException('Contact not found.');
    }
    return ref;
  }

  static Future<String> updateContact({
    required String elderId,
    required String contactId,
    required String fullName,
    required String relationship,
    required String contactNum,
    String emailAdd = '',
    String contactType = 'OTHER',
  }) async {
    await _elderIfLinked(elderId);
    final ref = await _contactOfElder(elderId, contactId);
    final fields = _contactForm(
      fullName: fullName,
      relationship: relationship,
      contactNum: contactNum,
      emailAdd: emailAdd,
      contactType: contactType,
    );
    final existing = await _activeContactDocs(elderId);
    if (existing.any(
      (d) =>
          d.id != contactId && d.data()['contact_num'] == fields['contact_num'],
    )) {
      throw LovedOneException('That number is already a contact.');
    }
    await ref.update({...fields, 'updated_at': FieldValue.serverTimestamp()});
    return 'Contact updated.';
  }

  /// Soft delete: kept for the record, but the device stops texting it.
  static Future<String> deleteContact({
    required String elderId,
    required String contactId,
  }) async {
    await _elderIfLinked(elderId);
    final ref = await _contactOfElder(elderId, contactId);
    await ref.update({
      'status': 'INACTIVE',
      'is_archived': true,
      'deleted_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
    return 'Contact removed.';
  }
}
