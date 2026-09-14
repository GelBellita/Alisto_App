import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/firestore_service.dart';
import 'main_nav_screen.dart';
import 'qr_scanner_screen.dart';

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
  bool _checking = false;

  @override
  void dispose() {
    _serialController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  Future<void> _scanQrCode() async {
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const QrScannerScreen()),
    );
    if (scanned == null || !mounted) return;
    setState(() => _serialController.text = scanned);
    // Go straight into validation once a code is scanned — no need to
    // make the user tap Continue separately after scanning.
    _handleContinue();
  }

  /// Validates the serial RIGHT HERE — against Firestore's `device`
  /// collection — before letting the user proceed. Previously this check
  /// only happened at the very end (final submit on the address screen),
  /// so a typo could slip through three more screens before the user
  /// found out the device didn't exist. Now it's caught immediately,
  /// whether the serial was typed or scanned via QR.
  Future<void> _handleContinue() async {
    final serial = _serialController.text.trim();
    if (serial.isEmpty) {
      _showError('Please enter your device serial number.');
      return;
    }

    setState(() => _checking = true);
    DeviceCheckResult result;
    try {
      result = await FirestoreService.checkDevice(serial);
    } catch (e) {
      if (!mounted) return;
      setState(() => _checking = false);
      _showError('Could not check the device right now. Please try again.');
      return;
    }
    if (!mounted) return;
    setState(() => _checking = false);

    if (!result.exists) {
      _showError(result.message);
      return;
    }

    // Someone already claimed this device — send the user into the "join"
    // flow (pre-filled with the elder's name, no duplicate elder_profile)
    // instead of asking for fresh elder info that would just be discarded.
    // Mirrors app.py's /check_device + auth.js's applyJoinMode() on web.
    if (result.alreadyRegistered) {
      if (!result.canJoin) {
        _showError(result.message);
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => JoinExistingElderScreen(
            serial: serial,
            elderFullName: result.elderFullName,
            elderDob: result.elderDob,
            elderAddress: result.elderAddress,
            elderSex: result.elderSex,
            elderData: result.elderData,
            deviceData: result.deviceData,
            familyCount: result.familyCount,
            familyLimit: result.familyLimit,
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PersonalInfoScreen(serial: serial),
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
                  currentStep: 2,
                  totalSteps: 4,
                ),
                const SizedBox(height: 24),
                Center(
                  child: DeviceStickerPreview(
                    serial: _serialController.text.trim(),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Enter the unique serial number found at the bottom of your ALISTO device, or scan its QR code.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _serialController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    suffixIcon: IconButton(
                      icon: const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: AppColors.primary,
                      ),
                      onPressed: _checking ? null : _scanQrCode,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Continue',
                  loading: _checking,
                  onPressed: _handleContinue,
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

  Future<void> _scanQrCode() async {
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const QrScannerScreen()),
    );
    if (scanned == null || !mounted) return;
    setState(() => _serialController.text = scanned);
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
                  decoration: InputDecoration(
                    suffixIcon: IconButton(
                      icon: const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: AppColors.primary,
                      ),
                      onPressed: _loading ? null : _scanQrCode,
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
// AUTO-JOIN — shown when the scanned/typed serial already belongs to
// someone else's elder
// =========================================================
/// Reached automatically from RegisterDeviceStep1Screen when
/// FirestoreService.checkDevice() reports the device is already claimed.
/// The elder's name is already on file (fetched from `elder_profile`), so
/// this screen only asks for the user's relationship to them, then links
/// the account the same way LinkDeviceScreen does — no new elder_profile
/// is created, and the serial never has to be re-typed.
class JoinExistingElderScreen extends StatefulWidget {
  final String serial;
  final String? elderFullName;
  final String? elderDob;
  final String? elderAddress;
  final String? elderSex;
  final Map<String, dynamic>? elderData;
  final Map<String, dynamic>? deviceData;
  final int familyCount;
  final int familyLimit;

  const JoinExistingElderScreen({
    super.key,
    required this.serial,
    required this.elderFullName,
    this.elderDob,
    this.elderAddress,
    this.elderSex,
    this.elderData,
    this.deviceData,
    required this.familyCount,
    required this.familyLimit,
  });

  @override
  State<JoinExistingElderScreen> createState() =>
      _JoinExistingElderScreenState();
}

class _JoinExistingElderScreenState extends State<JoinExistingElderScreen> {
  final _relationshipController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _relationshipController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  Future<void> _handleJoin() async {
    final relationship = _relationshipController.text.trim();
    if (relationship.isEmpty) {
      _showError('Please specify your relationship to the elder.');
      return;
    }

    setState(() => _loading = true);
    try {
      await FirestoreService.linkToExistingDevice(
        serial: widget.serial,
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

  String get _initials {
    final name = widget.elderFullName?.trim() ?? '';
    if (name.isEmpty) return '?';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  /// Turns a raw Firestore document map into ordered (label, value) pairs
  /// for display — every field that's actually on the document, not a
  /// hand-picked subset. [skip] lets the caller hide fields already shown
  /// elsewhere in the UI (e.g. full_name in the header).
  List<MapEntry<String, String>> _rowsFor(
    Map<String, dynamic>? data, {
    Set<String> skip = const {},
  }) {
    if (data == null) return const [];
    final entries = <MapEntry<String, String>>[];
    for (final key in data.keys) {
      if (skip.contains(key)) continue;
      entries.add(MapEntry(_prettifyKey(key), _formatValue(data[key])));
    }
    return entries;
  }

  String _prettifyKey(String key) {
    final spaced = key.replaceAll('_', ' ');
    return spaced
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  String _formatValue(dynamic value) {
    if (value == null) return 'Not on file';
    if (value is Timestamp) return value.toDate().toString();
    if (value is bool) return value ? 'Yes' : 'No';
    if (value is List) {
      return value.isEmpty ? 'Not on file' : value.join(', ');
    }
    final text = value.toString().trim();
    return text.isEmpty ? 'Not on file' : text;
  }

  @override
  Widget build(BuildContext context) {
    final hasName = widget.elderFullName?.trim().isNotEmpty ?? false;
    final name = hasName ? widget.elderFullName!.trim() : 'Unnamed';

    // Everything on the elder_profile doc, minus full_name (already shown
    // as the header) — this is what makes the card show "everything in
    // Firebase" instead of a fixed DOB/Sex/Address subset.
    final elderRows = _rowsFor(widget.elderData, skip: const {'full_name'});
    // Everything on the device doc too — status, simNumber, gps,
    // registeredAt, etc. — since that's also "what's in Firebase" for
    // this serial.
    final deviceRows = _rowsFor(widget.deviceData);

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
                  'Join This Device',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'This device is already linked to the elder below. '
                  'Their details are already on file — just confirm how '
                  'you are related.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 20),
                Center(child: DeviceStickerPreview(serial: widget.serial)),
                const SizedBox(height: 20),

                // ---- Elder profile card — every field on elder_profile,
                // not just a hand-picked subset. ----
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              _initials,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                                color: AppColors.primary,
                              ),
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
                                    fontSize: 16,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${widget.familyCount} of '
                                  '${widget.familyLimit} family slots used',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 28),
                      Text(
                        'Elder Profile (Firebase)',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                      if (elderRows.isEmpty)
                        const _ElderDetailRow(
                          icon: Icons.info_outline_rounded,
                          label: 'Profile',
                          value: null,
                        )
                      else
                        for (int i = 0; i < elderRows.length; i++) ...[
                          if (i > 0) const SizedBox(height: 10),
                          _ElderDetailRow(
                            icon: Icons.circle,
                            label: elderRows[i].key,
                            value: elderRows[i].value,
                          ),
                        ],
                    ],
                  ),
                ),

                if (deviceRows.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Device Record (Firebase)',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontSize: 13),
                        ),
                        const SizedBox(height: 10),
                        for (int i = 0; i < deviceRows.length; i++) ...[
                          if (i > 0) const SizedBox(height: 10),
                          _ElderDetailRow(
                            icon: Icons.smartphone_rounded,
                            label: deviceRows[i].key,
                            value: deviceRows[i].value,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                AppTextField(
                  label: 'Relationship to Elder',
                  controller: _relationshipController,
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Join & Continue',
                  loading: _loading,
                  onPressed: _handleJoin,
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

class _ElderDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  const _ElderDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.trim().isNotEmpty;
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
                hasValue ? value!.trim() : 'Not on file',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: hasValue
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
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
                  currentStep: 3,
                  totalSteps: 4,
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
                  currentStep: 4,
                  totalSteps: 4,
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