import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/firestore_service.dart';
import 'main_nav_screen.dart';
import 'wifi_setup_screen.dart';

// =========================================================
// STEP 1: SCAN / ENTER SERIAL
// =========================================================
class RegisterDeviceStep1Screen extends StatefulWidget {
  const RegisterDeviceStep1Screen({super.key});

  @override
  State<RegisterDeviceStep1Screen> createState() =>
      _RegisterDeviceStep1ScreenState();
}

class _RegisterDeviceStep1ScreenState extends State<RegisterDeviceStep1Screen> {
  final _serialController = TextEditingController();

  @override
  void dispose() {
    _serialController.dispose();
    super.dispose();
  }

  void _handleContinue() {
    if (_serialController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your device serial number.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            WifiSetupScreen(serial: _serialController.text.trim()),
      ),
    );
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
                  'Register Device',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const RegisterDeviceStepIndicator(
                  currentStep: 1,
                  totalSteps: 3,
                ),
                const SizedBox(height: 24),
                Center(
                  child: DeviceStickerPreview(
                    serial: _serialController.text.trim(),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Enter the unique serial number found at the bottom of your ALISTO device.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _serialController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    suffixIcon: Icon(
                      Icons.qr_code_scanner_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                PrimaryButton(label: 'Continue', onPressed: _handleContinue),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =========================================================
// LINK TO EXISTING DEVICE  (for "contact" role accounts)
// =========================================================
/// Lets a family member who was added as a "contact" (not the device
/// owner) join the elder/device someone else already registered, by
/// entering that device's serial number. Unlike RegisterDeviceStep1Screen,
/// this does NOT create a new elder_profile — see
/// FirestoreService.linkToExistingDevice.
class LinkDeviceScreen extends StatefulWidget {
  const LinkDeviceScreen({super.key});

  @override
  State<LinkDeviceScreen> createState() => _LinkDeviceScreenState();
}

class _LinkDeviceScreenState extends State<LinkDeviceScreen> {
  final _serialController = TextEditingController();
  final _relationshipController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _serialController.dispose();
    _relationshipController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  Future<void> _handleLink() async {
    final serial = _serialController.text.trim();
    final relationship = _relationshipController.text.trim();
    if (serial.isEmpty) {
      _showError('Please enter the device serial number.');
      return;
    }
    if (relationship.isEmpty) {
      _showError('Please specify your relationship to the elder.');
      return;
    }

    setState(() => _loading = true);
    try {
      await FirestoreService.linkToExistingDevice(
        serial: serial,
        relationship: relationship,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(
        e is StateError
            ? e.message
            : 'Could not link that device. Please try again.',
      );
      return;
    }

    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const MainNavScreen()),
      (route) => false,
    );
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
                  'Link Your Device',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Ask the device owner for the Alisto serial number, found '
                  'at the bottom of the device, then enter it below to see '
                  'the same alerts and reminders they do.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                Center(
                  child: DeviceStickerPreview(
                    serial: _serialController.text.trim(),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _serialController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    suffixIcon: Icon(
                      Icons.qr_code_scanner_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Relationship to Elder',
                  controller: _relationshipController,
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Link Device',
                  loading: _loading,
                  onPressed: _handleLink,
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

// =========================================================
// STEP 2: PERSONAL INFORMATION
// =========================================================
class PersonalInfoScreen extends StatefulWidget {
  final String serial;
  const PersonalInfoScreen({super.key, required this.serial});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  String _selectedSex = 'Female';
  DateTime? _selectedDob;
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 65, now.month, now.day),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
      helpText: 'Elder\'s date of birth',
    );
    if (picked != null) {
      setState(() => _selectedDob = picked);
    }
  }

  String get _dobLabel {
    if (_selectedDob == null) return 'Select date of birth';
    return '${_selectedDob!.year}-${_selectedDob!.month.toString().padLeft(2, '0')}-${_selectedDob!.day.toString().padLeft(2, '0')}';
  }

  void _handleContinue() {
    if (_nameController.text.trim().isEmpty || _selectedDob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SetHomeAddressScreen(
          serial: widget.serial,
          elderFullName: _nameController.text.trim(),
          elderDob: _dobLabel,
          elderSex: _selectedSex,
        ),
      ),
    );
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
                  'Elder\'s Personal Information',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const RegisterDeviceStepIndicator(
                  currentStep: 2,
                  totalSteps: 3,
                ),
                const SizedBox(height: 20),
                Center(
                  child: ProfileAvatarPicker(
                    onTap: () {
                      // TODO: open image picker / camera
                    },
                  ),
                ),
                const SizedBox(height: 20),
                AppTextField(
                  label: 'Name',
                  controller: _nameController,
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _DobPickerField(
                        label: _dobLabel,
                        onTap: _pickDob,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _SexDropdownField(
                        value: _selectedSex,
                        onChanged: (value) => setState(
                          () => _selectedSex = value ?? _selectedSex,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                PrimaryButton(label: 'Continue', onPressed: _handleContinue),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DobPickerField extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _DobPickerField({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Date of Birth', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: const InputDecoration(
              suffixIcon: Icon(Icons.calendar_today_rounded, size: 18),
            ),
            child: Text(label, style: const TextStyle(fontSize: 14)),
          ),
        ),
      ],
    );
  }
}

class _SexDropdownField extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;
  const _SexDropdownField({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sex', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          items: const [
            DropdownMenuItem(value: 'Female', child: Text('Female')),
            DropdownMenuItem(value: 'Male', child: Text('Male')),
          ],
          onChanged: onChanged,
          decoration: const InputDecoration(),
        ),
      ],
    );
  }
}

// =========================================================
// STEP 3: SET HOME ADDRESS
// =========================================================
class SetHomeAddressScreen extends StatefulWidget {
  final String serial;
  final String name;
  final String dob;
  final String sex;

  const SetHomeAddressScreen({
    super.key,
    required this.serial,
    required String elderFullName,
    required String elderDob,
    required String elderSex,
  }) : name = elderFullName,
       dob = elderDob,
       sex = elderSex;

  @override
  State<SetHomeAddressScreen> createState() => _SetHomeAddressScreenState();
}

class _SetHomeAddressScreenState extends State<SetHomeAddressScreen> {
  bool _loading = false;
  final _houseController = TextEditingController();
  final _zipController = TextEditingController();
  final _streetController = TextEditingController();
  final _barangayController = TextEditingController();
  final _cityController = TextEditingController();
  final _provinceController = TextEditingController();

  @override
  void dispose() {
    _houseController.dispose();
    _zipController.dispose();
    _streetController.dispose();
    _barangayController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_streetController.text.trim().isEmpty ||
        _barangayController.text.trim().isEmpty ||
        _cityController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in the required address fields.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Joined into a single string — matches how app.py's
    // _create_account_and_elder builds the elder_profile's address field.
    final address = [
      _houseController.text.trim(),
      _streetController.text.trim(),
      _barangayController.text.trim(),
      _cityController.text.trim(),
      _provinceController.text.trim(),
      _zipController.text.trim(),
    ].where((part) => part.isNotEmpty).join(', ');

    setState(() => _loading = true);
    try {
      await FirestoreService.registerDevice(
        serial: widget.serial,
        elderFullName: widget.name,
        elderDob: widget.dob,
        elderSex: widget.sex,
        address: address,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is StateError ? e.message : 'Something went wrong: $e'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RegistrationCompleteScreen(),
      ),
    );
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
                  'Set Home Address',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const RegisterDeviceStepIndicator(
                  currentStep: 3,
                  totalSteps: 3,
                ),
                const SizedBox(height: 20),
                Center(
                  child: Image.asset(
                    'assets/images/House.png',
                    height: context.clampHeight(0.16, min: 120, max: 170),
                    errorBuilder: (context, error, stackTrace) =>
                        const IllustrationPlaceholder(
                          icon: Icons.cottage_rounded,
                        ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: 'House / Unit No.',
                        controller: _houseController,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: AppTextField(
                        label: 'Zip Code',
                        keyboardType: TextInputType.number,
                        controller: _zipController,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Street / Purok',
                  controller: _streetController,
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: 'Barangay',
                        controller: _barangayController,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: AppTextField(
                        label: 'City',
                        controller: _cityController,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Province',
                  controller: _provinceController,
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Submit',
                  loading: _loading,
                  onPressed: _handleSubmit,
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

// =========================================================
// SUCCESS
// =========================================================
class RegistrationCompleteScreen extends StatelessWidget {
  const RegistrationCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ResponsiveContent(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: context.clampHeight(0.05, min: 20, max: 48)),
                Image.asset(
                  'assets/images/registrationcomplete.png',
                  height: context.clampHeight(0.22, min: 150, max: 210),
                  errorBuilder: (context, error, stackTrace) =>
                      const SuccessIllustration(),
                ),
                const SizedBox(height: 24),
                Text(
                  'Registration Complete',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Your Alisto device has been successfully registered.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                SizedBox(height: context.clampHeight(0.06, min: 32, max: 64)),
                PrimaryButton(
                  label: 'Add Contacts',
                  onPressed: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const MainNavScreen(initialIndex: 2),
                    ),
                    (route) => false,
                  ),
                ),
                const SizedBox(height: 12),
                SecondaryButton(
                  label: 'Go to Dashboard',
                  onPressed: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MainNavScreen(),
                    ),
                    (route) => false,
                  ),
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