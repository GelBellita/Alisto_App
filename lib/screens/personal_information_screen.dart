import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

/// Loose email check — good enough to catch typos before hitting Firebase,
/// which does the authoritative validation. Mirrors the pattern in
/// auth_screens.dart.
final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

// =========================================================
// PERSONAL INFORMATION — edit full name, email, phone.
// Reached from Profile > Personal Information.
// =========================================================
class PersonalInformationScreen extends StatefulWidget {
  const PersonalInformationScreen({super.key});

  @override
  State<PersonalInformationScreen> createState() =>
      _PersonalInformationScreenState();
}

class _PersonalInformationScreenState
    extends State<PersonalInformationScreen> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _initialized = false;
  bool _saving = false;
  String _originalEmail = '';

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.error : null,
      ),
    );
  }

  /// Prompts for the current password — needed by Firebase before an
  /// email change. Returns null if the user cancels.
  Future<String?> _promptCurrentPassword() async {
    final controller = TextEditingController();
    bool obscure = true;
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Confirm your password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Changing your email requires your current password.',
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    obscureText: obscure,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Current password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                        ),
                        onPressed: () =>
                            setDialogState(() => obscure = !obscure),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.pop(dialogContext, controller.text),
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleSave() async {
    final fullName = _fullNameController.text.trim();
    final phone = _phoneController.text.trim();
    final newEmail = _emailController.text.trim();

    if (fullName.isEmpty) {
      _showMessage('Please enter your full name.', error: true);
      return;
    }
    if (newEmail.isEmpty || !_emailPattern.hasMatch(newEmail)) {
      _showMessage('Please enter a valid email address.', error: true);
      return;
    }

    final emailChanged = newEmail != _originalEmail;

    String? currentPassword;
    if (emailChanged) {
      currentPassword = await _promptCurrentPassword();
      if (currentPassword == null || currentPassword.isEmpty) {
        // Cancelled — don't save anything, including the name/phone
        // edits, so "Save" stays an all-or-nothing action.
        return;
      }
    }

    setState(() => _saving = true);
    try {
      if (emailChanged) {
        final error = await AuthService.updateEmail(
          currentPassword: currentPassword!,
          newEmail: newEmail,
        );
        if (error != null) {
          _showMessage(error, error: true);
          return;
        }
      }

      await FirestoreService.updateUserProfile(
        fullName: fullName,
        phone: phone,
        email: emailChanged ? newEmail : null,
      );

      if (emailChanged) {
        _originalEmail = newEmail;
        _showMessage(
          'Details saved. Check your new email inbox to confirm the '
          'address — you\'ll need to use it next time you log in.',
        );
      } else {
        _showMessage('Details saved.');
      }
    } catch (e) {
      _showMessage('Could not save your changes. Please try again.',
          error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleSpacing: 0,
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.textPrimary,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Text(
          'Personal Information',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontSize: 18),
        ),
      ),
      body: ResponsiveContent(
        child: StreamBuilder<dynamic>(
          stream: FirestoreService.userProfileStream(),
          builder: (context, snapshot) {
            if (!_initialized && snapshot.hasData) {
              final data = snapshot.data?.data() as Map<String, dynamic>?;
              _fullNameController.text = (data?['full_name'] ?? '').toString();
              _originalEmail = (data?['email'] ?? '').toString();
              _emailController.text = _originalEmail;
              _phoneController.text =
                  (data?['contact_number'] ?? '').toString();
              _initialized = true;
            }

            if (!_initialized) {
              return const Center(child: CircularProgressIndicator());
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppTextField(
                    label: 'Full Name',
                    controller: _fullNameController,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    controller: _emailController,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Phone Number',
                    keyboardType: TextInputType.phone,
                    controller: _phoneController,
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: 'Save Changes',
                    loading: _saving,
                    onPressed: _handleSave,
                  ),
                  const SizedBox(height: 22),
                  const _SettingsGroupLabel('Security'),
                  const SizedBox(height: 8),
                  _PersonalInfoNavTile(
                    icon: Icons.lock_rounded,
                    color: Accent.blue,
                    title: 'Change Password',
                    subtitle: 'Update your account password',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChangePasswordScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SettingsGroupLabel extends StatelessWidget {
  final String text;
  const _SettingsGroupLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _PersonalInfoNavTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _PersonalInfoNavTile({
    required this.icon,
    required this.color,
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

// =========================================================
// CHANGE PASSWORD — current password + new password + confirm.
// Reached from Personal Information and from Settings > Security.
// =========================================================
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Repaints the live password checklist on every keystroke.
    _newController.addListener(_onNewPasswordChanged);
  }

  void _onNewPasswordChanged() => setState(() {});

  @override
  void dispose() {
    _currentController.dispose();
    _newController.removeListener(_onNewPasswordChanged);
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.error : null,
      ),
    );
  }

  Future<void> _handleSave() async {
    final current = _currentController.text;
    final newPassword = _newController.text;
    final confirm = _confirmController.text;

    if (current.isEmpty || newPassword.isEmpty || confirm.isEmpty) {
      _showMessage('Please fill in all three fields.', error: true);
      return;
    }
    if (!passwordMeetsRequirements(newPassword)) {
      _showMessage(
        'New password must meet all the requirements listed below.',
        error: true,
      );
      return;
    }
    if (newPassword != confirm) {
      _showMessage('New password and confirmation do not match.',
          error: true);
      return;
    }

    setState(() => _saving = true);
    final error = await AuthService.changePassword(
      currentPassword: current,
      newPassword: newPassword,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (error != null) {
      _showMessage(error, error: true);
      return;
    }
    _showMessage('Password updated.');
    Navigator.pop(context);
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
                  'Change Password',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'Enter your current password, then choose a new one.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                AppTextField(
                  label: 'Current Password',
                  hint: '••••••••',
                  obscureText: _obscureCurrent,
                  controller: _currentController,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureCurrent
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                    ),
                    onPressed: () =>
                        setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'New Password',
                  hint: '••••••••',
                  obscureText: _obscureNew,
                  controller: _newController,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNew
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                    ),
                    onPressed: () =>
                        setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
                const SizedBox(height: 8),
                PasswordStrengthChecklist(password: _newController.text),
                const SizedBox(height: 8),
                AppTextField(
                  label: 'Confirm New Password',
                  hint: '••••••••',
                  obscureText: _obscureConfirm,
                  controller: _confirmController,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                const SizedBox(height: 28),
                PrimaryButton(
                  label: 'Update Password',
                  loading: _saving,
                  onPressed: _handleSave,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}