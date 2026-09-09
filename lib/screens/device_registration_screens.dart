import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/firestore_service.dart';
import 'main_nav_screen.dart';

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
            PersonalInfoScreen(serial: _serialController.text.trim()),
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
                    hintText: '2026-0718ALISTO09X3',
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
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _contactController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  void _handleContinue() {
    if (_nameController.text.trim().isEmpty ||
        _ageController.text.trim().isEmpty ||
        _contactController.text.trim().isEmpty) {
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
          name: _nameController.text.trim(),
          age: _ageController.text.trim(),
          sex: _selectedSex,
          contactNumber: _contactController.text.trim(),
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
                  'Personal Information',
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
                  hint: 'Maria Santos',
                  controller: _nameController,
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: 'Age',
                        hint: '65',
                        keyboardType: TextInputType.number,
                        controller: _ageController,
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
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Contact Number',
                  hint: '0917 123 4567',
                  keyboardType: TextInputType.phone,
                  controller: _contactController,
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
  final String age;
  final String sex;
  final String contactNumber;

  const SetHomeAddressScreen({
    super.key,
    required this.serial,
    required this.name,
    required this.age,
    required this.sex,
    required this.contactNumber,
  });

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

  @override
  void dispose() {
    _houseController.dispose();
    _zipController.dispose();
    _streetController.dispose();
    _barangayController.dispose();
    _cityController.dispose();
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

    setState(() => _loading = true);
    try {
      await FirestoreService.savePersonalInfo(
        fullName: widget.name, // was: name: widget.name
        age: widget.age,
        sex: widget.sex,
        contactNumber: widget.contactNumber,
      );
      await FirestoreService.saveAddress(
        houseNo: _houseController.text.trim(),
        zip: _zipController.text.trim(),
        street: _streetController.text.trim(),
        barangay: _barangayController.text.trim(),
        city: _cityController.text.trim(),
      );
      await FirestoreService.registerDevice(serial: widget.serial);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Something went wrong: $e'),
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
                        hint: '123',
                        controller: _houseController,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: AppTextField(
                        label: 'Zip Code',
                        hint: '6000',
                        keyboardType: TextInputType.number,
                        controller: _zipController,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Street / Purok',
                  hint: 'Purok 4, Labangon',
                  controller: _streetController,
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: 'Barangay',
                        hint: 'Labangon',
                        controller: _barangayController,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: AppTextField(
                        label: 'City',
                        hint: 'Cebu City',
                        controller: _cityController,
                      ),
                    ),
                  ],
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
