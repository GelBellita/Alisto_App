import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/user_avatar.dart';
import '../services/firestore_service.dart';
import '../models/app_models.dart';
import 'medicine_screens.dart';

/// How many reminders the Home card previews before "View All" is needed.
const int _kHomeMedicinePreviewCount = 3;

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ResponsiveContent(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _HomeHeader(),
              const SizedBox(height: 18),
              const _DeviceStatusCard(),
              const SizedBox(height: 16),
              const _MedicineReminderCard(),
              const SizedBox(height: 18),
              const SectionLabel('Quick Actions'),
              const SizedBox(height: 10),
              const _QuickActionsRow(),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// HEADER — shows the logged-in user's real name and photo
// ---------------------------------------------------------
class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<dynamic>(
      stream: FirestoreService.userProfileStream(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final name = (data?['full_name'] ?? '').toString();
        final photo = data?['photoBase64'] as String?;
        final firstName = name.trim().isEmpty
            ? ''
            : name.trim().split(RegExp(r'\s+')).first;

        return Row(
          children: [
            UserAvatar(base64Image: photo, size: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    firstName.isEmpty ? 'Hello!' : 'Hello, $firstName!',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontSize: 18),
                  ),
                  Text(
                    'Stay safe today.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.primary,
              size: 26,
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------
// DEVICE STATUS CARD
// Alerts count | SIM number (falls back to the owner's phone)
// GPS          | Last alert
// ---------------------------------------------------------
class _DeviceStatusCard extends StatelessWidget {
  const _DeviceStatusCard();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<dynamic>(
      stream: FirestoreService.deviceStream(),
      builder: (context, deviceSnapshot) {
        final device = deviceSnapshot.data?.data() as Map<String, dynamic>?;
        final status = device?['status'] ?? 'Offline';
        final deviceSim = (device?['simNumber'] ?? '').toString().trim();

        return StreamBuilder<dynamic>(
          stream: FirestoreService.userProfileStream(),
          builder: (context, profileSnapshot) {
            final profile =
                profileSnapshot.data?.data() as Map<String, dynamic>?;
            final ownerPhone = (profile?['contact_number'] ?? '')
                .toString()
                .trim();

            // The device document seeds simNumber with a placeholder dash
            // until the SIM is actually read from the hardware, so show the
            // owner's own number in the meantime instead of a blank tile.
            final hasDeviceSim = deviceSim.isNotEmpty && deviceSim != '—';
            final simNumber = hasDeviceSim
                ? deviceSim
                : (ownerPhone.isEmpty ? '—' : ownerPhone);

            return AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Device Status',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontSize: 15),
                      ),
                      StatusPill(
                        label: status,
                        color: status == 'Online'
                            ? Accent.green
                            : AppColors.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: StreamBuilder<int>(
                          stream: FirestoreService.alertsCountStream(),
                          builder: (context, alertsSnapshot) {
                            final count = alertsSnapshot.data ?? 0;
                            return _StatTile(
                              icon: Icons.notifications_active_rounded,
                              color: AppColors.error,
                              label: 'Number of Alerts',
                              value: '$count',
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatTile(
                          icon: Icons.sim_card_rounded,
                          color: Accent.blue,
                          label: 'Sim Number',
                          value: simNumber,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Expanded(child: _GpsTile()),
                      const SizedBox(width: 10),
                      const Expanded(child: _LastAlertTile()),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Most recent alert written by the device (Raspberry Pi/Flask server).
class _LastAlertTile extends StatelessWidget {
  const _LastAlertTile();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AlertModel?>(
      stream: FirestoreService.latestAlertStream(),
      builder: (context, snapshot) {
        final alert = snapshot.data;
        final isEmergency = alert?.type == 'emergency';

        return _StatTile(
          icon: Icons.history_rounded,
          color: isEmergency ? AppColors.error : Accent.yellow,
          label: 'Last Alert',
          value: alert == null
              ? 'None yet'
              : (alert.title.isEmpty
                    ? _alertTypeLabel(alert.type)
                    : alert.title),
          subValue: alert?.time,
        );
      },
    );
  }

  static String _alertTypeLabel(String type) {
    switch (type) {
      case 'emergency':
        return 'Emergency';
      case 'medicine':
        return 'Medicine';
      case 'battery':
        return 'Low Battery';
      default:
        return 'System';
    }
  }
}

/// Most recent GPS ping written to `DEVICE_LOCATION` by the Raspberry
/// Pi/Flask server — mirrors the web dashboard's "Last Known Location"
/// panel. Tapping opens the full location screen (address, coordinates,
/// map) — same idea as the web's "View on Map" button.
class _GpsTile extends StatelessWidget {
  const _GpsTile();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<LocationModel?>(
      stream: FirestoreService.latestLocationStream(),
      builder: (context, snapshot) {
        final location = snapshot.data;
        final hasAddress = location != null && location.address.isNotEmpty;

        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DeviceLocationScreen(),
            ),
          ),
          child: _StatTile(
            icon: Icons.location_on_rounded,
            color: Accent.purple,
            label: 'GPS',
            value: hasAddress ? location.address : 'Waiting for signal',
            subValue: _relativeTime(location?.recordedAt),
          ),
        );
      },
    );
  }
}

/// Turns a timestamp into a short "Xm ago" / "Xh ago" label. Returns an
/// empty string (so the caller's subValue row just doesn't render) when
/// there's nothing to show yet.
String _relativeTime(DateTime? time) {
  if (time == null) return '';
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String? subValue;
  const _StatTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.subValue,
  });

  @override
  Widget build(BuildContext context) {
    final sub = subValue?.trim() ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (sub.isNotEmpty)
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// MEDICINE REMINDER CARD — live from Firestore
// ---------------------------------------------------------
class _MedicineReminderCard extends StatelessWidget {
  const _MedicineReminderCard();

  void _openAll(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AllMedicinesScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Medicine Reminder',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontSize: 15),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _openAll(context),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        'View All',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          StreamBuilder<dynamic>(
            stream: FirestoreService.medicinesStream(),
            builder: (context, snapshot) {
              // Check hasError BEFORE hasData — a stream that fails (e.g.
              // missing Firestore composite index, or no device linked
              // yet) never sets hasData to true, so checking hasData
              // first meant this card spun forever instead of ever
              // showing what actually went wrong.
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Could not load reminders: ${snapshot.error}',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.error),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              final docs = snapshot.data;
              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No medicine reminders yet. Add one below.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              }
              final medicines = docs
                  .map<MedicineModel>((d) => MedicineModel.fromDoc(d))
                  .toList();
              final preview = medicines.length > _kHomeMedicinePreviewCount
                  ? medicines.sublist(0, _kHomeMedicinePreviewCount)
                  : medicines;
              final hidden = medicines.length - preview.length;

              return Column(
                children: [
                  for (int i = 0; i < preview.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _MedicineRow(medicine: preview[i]),
                  ],
                  if (hidden > 0) ...[
                    const SizedBox(height: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _openAll(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '+ $hidden more reminder${hidden == 1 ? '' : 's'}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.notifications_none_rounded,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                "Stay on track. Don't forget your medicine",
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(fontSize: 11.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MedicineRow extends StatelessWidget {
  final MedicineModel medicine;
  const _MedicineRow({required this.medicine});

  @override
  Widget build(BuildContext context) {
    final notified = medicine.status == 'Notified';
    final color = notified ? AppColors.primary : AppColors.textSecondary;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => showMedicineSheet(context, existing: medicine),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    medicine.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                  Text(
                    medicine.time,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            StatusPill(label: medicine.status, color: color),
            const SizedBox(width: 4),
            const Icon(
              Icons.edit_rounded,
              size: 14,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// QUICK ACTIONS
// ---------------------------------------------------------
class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionCard(
            icon: Icons.medication_rounded,
            title: 'Add Medicine',
            subtitle: 'Set medicine details and reminder schedules',
            onTap: () => showMedicineSheet(context),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.gps_fixed_rounded,
            title: 'Find Alisto',
            subtitle: 'View the current location of the Alisto device',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const DeviceLocationScreen(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: AppColors.primary),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.textSecondary,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// ---------------------------------------------------------
// DEVICE LOCATION — full-screen equivalent of the web dashboard's
// "Last Known Location" panel + its "View on Map" modal, combined.
// Reads the same DEVICE_LOCATION data via
// FirestoreService.latestLocationStream().
// ---------------------------------------------------------
class DeviceLocationScreen extends StatelessWidget {
  const DeviceLocationScreen({super.key});

  void _copy(BuildContext context, String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label copied')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MinimalBackAppBar(),
      body: SafeArea(
        top: false,
        child: ResponsiveContent(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  'Device Location',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'The last GPS position reported by the Alisto device.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 20),
                StreamBuilder<LocationModel?>(
                  stream: FirestoreService.latestLocationStream(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData && snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final location = snapshot.data;
                    if (location == null || location.address.isEmpty) {
                      return AppCard(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.location_off_rounded,
                              size: 32,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'No location reported yet',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'This device hasn\'t sent a GPS update yet. '
                              'Location appears here once it does.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (location.hasCoordinates)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: SizedBox(
                              height: 220,
                              width: double.infinity,
                              child: FlutterMap(
                                options: MapOptions(
                                  initialCenter: LatLng(
                                    location.latitude!,
                                    location.longitude!,
                                  ),
                                  initialZoom: 16,
                                  interactionOptions: const InteractionOptions(
                                    flags: InteractiveFlag.pinchZoom |
                                        InteractiveFlag.drag,
                                  ),
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate:
                                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName: 'com.alisto.app',
                                  ),
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        point: LatLng(
                                          location.latitude!,
                                          location.longitude!,
                                        ),
                                        width: 40,
                                        height: 40,
                                        child: const Icon(
                                          Icons.location_on_rounded,
                                          color: AppColors.error,
                                          size: 36,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const RichAttributionWidget(
                                    attributions: [
                                      TextSourceAttribution(
                                        'OpenStreetMap contributors',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        AppCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _LocationDetailRow(
                                icon: Icons.location_on_rounded,
                                label: 'Address',
                                value: location.address,
                                onCopy: () => _copy(
                                  context,
                                  location.address,
                                  'Address',
                                ),
                              ),
                              const SizedBox(height: 12),
                              _LocationDetailRow(
                                icon: Icons.access_time_rounded,
                                label: 'Last Updated',
                                value: location.recordedAt == null
                                    ? 'Unknown'
                                    : '${_relativeTime(location.recordedAt)} '
                                          '(${location.recordedAt})',
                              ),
                              if (location.hasCoordinates) ...[
                                const SizedBox(height: 12),
                                _LocationDetailRow(
                                  icon: Icons.my_location_rounded,
                                  label: 'Coordinates',
                                  value:
                                      '${location.latitude!.toStringAsFixed(6)}, '
                                      '${location.longitude!.toStringAsFixed(6)}',
                                  onCopy: () => _copy(
                                    context,
                                    '${location.latitude}, ${location.longitude}',
                                    'Coordinates',
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onCopy;
  const _LocationDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        if (onCopy != null)
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onCopy,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.copy_rounded,
                size: 15,
                color: AppColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}