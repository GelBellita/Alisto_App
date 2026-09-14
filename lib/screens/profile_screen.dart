import 'dart:convert';

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
              const _ProfileNavTile(
                icon: Icons.smartphone_rounded,
                color: Accent.blue,
                title: 'Device Information',
                subtitle: 'View details about your Alisto device',
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