import 'package:flutter/material.dart';

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
        // 'name' is the legacy field from accounts created before the
        // signup form was changed to Full Name.
        final name = (data?['fullName'] ?? data?['name'] ?? '').toString();
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
        final gps = device?['gps'] ?? '—';
        final deviceSim = (device?['simNumber'] ?? '').toString().trim();

        return StreamBuilder<dynamic>(
          stream: FirestoreService.userProfileStream(),
          builder: (context, profileSnapshot) {
            final profile =
                profileSnapshot.data?.data() as Map<String, dynamic>?;
            final personalInfo =
                profile?['personalInfo'] as Map<String, dynamic>?;
            final ownerPhone =
                (personalInfo?['contactNumber'] ?? profile?['phone'] ?? '')
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
                      Expanded(
                        child: _StatTile(
                          icon: Icons.location_on_rounded,
                          color: Accent.purple,
                          label: 'GPS',
                          value: gps,
                        ),
                      ),
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
              final docs = snapshot.data.docs;
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
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Live location comes from the device once it starts sending GPS updates.',
                  ),
                ),
              );
            },
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
