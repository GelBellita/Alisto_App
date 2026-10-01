import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/user_avatar.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'settings_screen.dart';
import 'auth_screens.dart';
import 'help_support_screen.dart';
import 'legal_screens.dart';
import 'personal_information_screen.dart';
import 'home_screen.dart' show DeviceLocationScreen;
import 'wifi_setup_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 34),
                  Text(
                    'Profile',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontSize: 18),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        Icons.settings_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const _ProfileHeaderCard(),
              const SizedBox(height: 18),
              _ProfileNavTile(
                icon: Icons.person_rounded,
                color: Accent.purple,
                title: 'Personal Information',
                subtitle: 'View and manage your personal details',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PersonalInformationScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _ProfileNavTile(
                icon: Icons.smartphone_rounded,
                color: Accent.blue,
                title: 'Device Information',
                subtitle: 'View details about your Alisto device',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DeviceInformationScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _ProfileNavTile(
                icon: Icons.support_agent_rounded,
                color: Accent.yellow,
                title: 'Help & Support',
                subtitle: 'FAQs, guides and customer support',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HelpSupportScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _ProfileNavTile(
                icon: Icons.smartphone_rounded,
                color: AppColors.textSecondary,
                title: 'About Alisto',
                subtitle: 'App information and terms',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TermsPrivacyScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              _LogOutButton(
                onTap: () async {
                  await AuthService.logout();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WelcomeScreen(),
                      ),
                      (route) => false,
                    );
                  }
                },
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  'App Version 1.0.0',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// DEVICE INFORMATION — read-only view of the device/{serial} doc this
// account is linked to, plus which elder it's protecting and a shortcut
// to the same location view used from the Home screen's GPS card.
// ---------------------------------------------------------
/// Walks the user through moving Alisto to a new WiFi network -- e.g.
/// after physically relocating the device to a different house/room with
/// a different network. Reuses the exact same setup flow as first-time
/// onboarding (WifiSetupScreen), which already knows how to reach the
/// device's own temporary "Alisto-Setup" hotspot; only the destination
/// after a successful connect differs (isReconfiguring: true returns
/// here instead of continuing into device registration).
void _showChangeWifiInstructions(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Change WiFi Network'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('If you moved Alisto somewhere with a different WiFi, follow these steps:'),
          SizedBox(height: 12),
          _WifiStep(number: '1', text: 'Unplug Alisto\'s power, wait 10 seconds, then plug it back in.'),
          SizedBox(height: 8),
          _WifiStep(number: '2', text: 'Wait about 30 seconds for it to start its own "Alisto-Setup" WiFi network.'),
          SizedBox(height: 8),
          _WifiStep(number: '3', text: 'On your phone, open WiFi settings and connect to "Alisto-Setup".'),
          SizedBox(height: 8),
          _WifiStep(number: '4', text: 'Come back here and tap Continue to enter the new WiFi name and password.'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const WifiSetupScreen(isReconfiguring: true),
              ),
            );
          },
          child: const Text('Continue', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}

class _WifiStep extends StatelessWidget {
  final String number;
  final String text;
  const _WifiStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
          child: Text(
            number,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.35)),
        ),
      ],
    );
  }
}

class DeviceInformationScreen extends StatelessWidget {
  const DeviceInformationScreen({super.key});

  String _formatDate(dynamic value) {
    if (value is! Timestamp) return 'Unknown';
    final d = value.toDate();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
                  'Device Information',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'Details about the Alisto device linked to this account.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 20),
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
                  stream: FirestoreService.deviceStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final device = snapshot.data?.data();
                    if (device == null) {
                      return AppCard(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.smartphone_rounded,
                              size: 32,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'No device linked yet',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Register or join an Alisto device to see its '
                              'details here.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      );
                    }

                    final serial = (device['serial_number'] ?? '—').toString();
                    final storedStatus = (device['status'] ?? 'Offline').toString();
                    final lastSeenRaw = device['last_seen'];
                    final simRaw = (device['simNumber'] ?? '').toString().trim();
                    final simNumber = simRaw.isEmpty || simRaw == '—' ? 'Not set yet' : simRaw;
                    final registeredOn = _formatDate(device['registeredAt']);
                    final elderId = device['elder_id'] as String?;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      serial,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  LiveDeviceStatus(
                                    storedStatus: storedStatus,
                                    lastSeenRaw: lastSeenRaw,
                                    builder: (context, status) => StatusPill(
                                      label: status,
                                      color: status == 'Online'
                                          ? Accent.green
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Serial Number',
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 14),
                              const AppDivider(),
                              const SizedBox(height: 14),
                              _SimNumberRow(
                                serial: serial,
                                simNumber: simNumber,
                              ),
                              const SizedBox(height: 12),
                              _DeviceDetailRow(
                                icon: Icons.event_available_rounded,
                                label: 'Registered On',
                                value: registeredOn,
                              ),
                              if (elderId != null) ...[
                                const SizedBox(height: 12),
                                _ElderNameRow(elderId: elderId),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _ProfileNavTile(
                          icon: Icons.location_on_rounded,
                          color: Accent.purple,
                          title: 'Device Location',
                          subtitle: 'View the last known location on a map',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DeviceLocationScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _ProfileNavTile(
                          icon: Icons.wifi_rounded,
                          color: Accent.blue,
                          title: 'Change WiFi Network',
                          subtitle: 'Moved Alisto somewhere new? Connect it to a different WiFi',
                          onTap: () => _showChangeWifiInstructions(context),
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

class _DeviceDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DeviceDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// SIM Number, editable -- the device can't reliably read its own phone
/// number off the SIM card via AT commands (most prepaid SIMs never have
/// the MSISDN stored on them, so an AT+CNUM query usually comes back
/// empty), so this is entered manually here and pushed straight to
/// Firestore's device/{serial}.simNumber instead of being auto-detected.
class _SimNumberRow extends StatelessWidget {
  final String serial;
  final String simNumber;
  const _SimNumberRow({required this.serial, required this.simNumber});

  Future<void> _edit(BuildContext context) async {
    final controller = TextEditingController(
      text: simNumber == 'Not set yet' ? '' : simNumber,
    );
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('SIM Number'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The device can\'t reliably read its own number from the SIM '
              'card, so please enter it manually.',
              style: Theme.of(dialogContext).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Phone Number',
              controller: controller,
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty || !context.mounted) return;
    try {
      await FirestoreService.setDeviceSimNumber(serial, result);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save the SIM number: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _edit(context),
      child: Row(
        children: [
          const Icon(Icons.sim_card_rounded, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'SIM Number',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ),
          Text(
            simNumber,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.edit_rounded, size: 14, color: AppColors.primary),
        ],
      ),
    );
  }
}

/// One-time lookup of the elder this device is linked to -- elder_profile
/// rarely changes (only on re-registration/relinking), so this doesn't
/// need to be a live stream like the rest of this screen.
class _ElderNameRow extends StatelessWidget {
  final String elderId;
  const _ElderNameRow({required this.elderId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('elder_profile').doc(elderId).get(),
      builder: (context, snapshot) {
        final name = snapshot.data?.data()?['full_name']?.toString();
        return _DeviceDetailRow(
          icon: Icons.favorite_rounded,
          label: 'Protecting',
          value: (name == null || name.isEmpty) ? '—' : name,
        );
      },
    );
  }
}

class _ProfileHeaderCard extends StatefulWidget {
  const _ProfileHeaderCard();

  @override
  State<_ProfileHeaderCard> createState() => _ProfileHeaderCardState();
}

class _ProfileHeaderCardState extends State<_ProfileHeaderCard> {
  bool _savingPhoto = false;

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.error : null,
      ),
    );
  }

  /// Lets the user pick or take a photo, then stores it on their Firestore
  /// user document as a base64 string. Images are downscaled by the picker
  /// itself (512px, quality 70) so the encoded result stays small.
  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 70,
      );
      if (picked == null) return;

      setState(() => _savingPhoto = true);
      final bytes = await picked.readAsBytes();
      final encoded = base64Encode(bytes);

      if (encoded.length > FirestoreService.maxPhotoBytes) {
        _showMessage(
          'That photo is too large. Please choose a different one.',
          error: true,
        );
        return;
      }

      await FirestoreService.saveProfilePhoto(encoded);
      _showMessage('Profile photo updated.');
    } catch (e) {
      _showMessage(
        'Could not update the photo. Please try again.',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _savingPhoto = false);
    }
  }

  Future<void> _removePhoto() async {
    setState(() => _savingPhoto = true);
    try {
      await FirestoreService.removeProfilePhoto();
      _showMessage('Profile photo removed.');
    } catch (e) {
      _showMessage('Could not remove the photo.', error: true);
    } finally {
      if (mounted) setState(() => _savingPhoto = false);
    }
  }

  void _openPhotoOptions({required bool hasPhoto}) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Profile Photo',
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              ListTile(
                leading: const Icon(
                  Icons.photo_camera_rounded,
                  color: AppColors.primary,
                ),
                title: const Text('Take a photo'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickPhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_rounded,
                  color: AppColors.primary,
                ),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickPhoto(ImageSource.gallery);
                },
              ),
              if (hasPhoto)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
                  ),
                  title: const Text(
                    'Remove photo',
                    style: TextStyle(color: AppColors.error),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _removePhoto();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<dynamic>(
      stream: FirestoreService.userProfileStream(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        // Matches FirestoreService.createUserProfile()'s field names
        // exactly (full_name / contact_number / role: 'family'). The old
        // fallbacks (fullName, phone, personalInfo.contactNumber,
        // device_owner/contact roles) were from a camelCase schema this
        // app no longer writes, which is why every field but email was
        // showing '—'.
        final name = (data?['full_name'] ?? '—').toString();
        final photo = data?['photoBase64'] as String?;
        final email = (data?['email'] ?? '').toString();
        final contactNumber = (data?['contact_number'] ?? '—').toString();
        final roleRaw = (data?['role'] ?? '').toString();
        final role = roleRaw.isEmpty
            ? '—'
            : roleRaw[0].toUpperCase() + roleRaw.substring(1);

        // Age/address aren't stored on user_account at all — those belong
        // to elder_profile (the loved one's record, not the account
        // holder's). Left blank here; wire up a real elder lookup if this
        // card should show them.
        const age = '';
        const addressLine = '';

        return AppCard(
          color: AppColors.primary.withOpacity(0.07),
          borderColor: AppColors.primary.withOpacity(0.18),
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(40),
                onTap: _savingPhoto
                    ? null
                    : () => _openPhotoOptions(
                        hasPhoto: photo != null && photo.isNotEmpty,
                      ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    UserAvatar(base64Image: photo, size: 78),
                    if (_savingPhoto)
                      Container(
                        width: 78,
                        height: 78,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35),
                          shape: BoxShape.circle,
                        ),
                        child: const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.background,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.photo_camera_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        role,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (age.toString().isNotEmpty)
                      _ProfileMetaRow(
                        icon: Icons.cake_rounded,
                        text: '$age years old',
                      ),
                    if (addressLine.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _ProfileMetaRow(
                        icon: Icons.location_on_rounded,
                        text: addressLine,
                      ),
                    ],
                    const SizedBox(height: 4),
                    _ProfileMetaRow(
                      icon: Icons.call_rounded,
                      text: contactNumber.toString(),
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _ProfileMetaRow(
                        icon: Icons.mail_outline_rounded,
                        text: email,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProfileMetaRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ProfileMetaRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileNavTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const _ProfileNavTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap ?? () {},
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withOpacity(0.14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 19, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _LogOutButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LogOutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.error.withOpacity(0.12),
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, size: 17, color: AppColors.error),
              SizedBox(width: 8),
              Text(
                'Log Out',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}