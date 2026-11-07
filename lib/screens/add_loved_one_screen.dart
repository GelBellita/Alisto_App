import 'package:flutter/material.dart';

import '../models/loved_one_models.dart';
import '../services/barangays.dart';
import '../services/loved_ones_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/loved_one_widgets.dart';
import 'qr_scanner_screen.dart';

enum _Pane { device, existing, newOne, done }

// =========================================================
// ADD A LOVED ONE — the web's "Add a loved one" window, step for step:
//   1. Device  -> type or scan the Device ID (or "I don't have the
//                 device with me yet")
//   2a. Device already has an elder -> confirm + pick relationship (join)
//   2b. Free device / no device     -> fill in their details (add)
//   3. Done
// Pops with `true` when something was added, so the list refreshes.
// =========================================================
class AddLovedOneScreen extends StatefulWidget {
  const AddLovedOneScreen({super.key});

  @override
  State<AddLovedOneScreen> createState() => _AddLovedOneScreenState();
}

class _AddLovedOneScreenState extends State<AddLovedOneScreen> {
  _Pane _pane = _Pane.device;
  bool _busy = false;
  String? _alert;
  String _doneMessage = '';

  // step 1
  final _deviceCtrl = TextEditingController();
  DeviceLookup? _lookup; // null deviceId -> no device

  // step 2a (join)
  String? _joinRelationship;
  final _joinOtherCtrl = TextEditingController();

  // step 2b (new)
  final _nameCtrl = TextEditingController();
  String? _dob;
  String? _relationship;
  final _relOtherCtrl = TextEditingController();
  final _occupationCtrl = TextEditingController();
  final _houseCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  String? _barangay;
  final _cityCtrl = TextEditingController();
  final _provinceCtrl = TextEditingController();
  final _zipCtrl = TextEditingController();

  @override
  void dispose() {
    for (final c in [
      _deviceCtrl, _joinOtherCtrl, _nameCtrl, _relOtherCtrl, _occupationCtrl,
      _houseCtrl, _streetCtrl, _cityCtrl, _provinceCtrl, _zipCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _show(_Pane pane) => setState(() {
        _pane = pane;
        _alert = null;
      });

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _alert = null;
    });
    try {
      await action();
    } on LovedOneException catch (e) {
      if (mounted) setState(() => _alert = e.message);
    } catch (e) {
      if (mounted) {
        setState(() => _alert = 'Something went wrong. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------- step 1 ----------
  Future<void> _scan() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (code == null || !mounted) return;
    _deviceCtrl.text = code;
    _checkDevice();
  }

  void _checkDevice() {
    final id = LovedOnesService.cleanDeviceId(_deviceCtrl.text);
    if (id.isEmpty) {
      setState(() => _alert =
          'Enter the Device ID, or scan the QR code on the device.');
      return;
    }
    _run(() async {
      final lookup = await LovedOnesService.checkDevice(id);
      _lookup = lookup;
      _show(lookup.isExisting ? _Pane.existing : _Pane.newOne);
    });
  }

  // ---------- step 2a ----------
  void _join() {
    if (_joinRelationship == null) {
      setState(() => _alert = 'Choose how you are related to them.');
      return;
    }
    if (_joinRelationship == 'Other' && _joinOtherCtrl.text.trim().isEmpty) {
      setState(() => _alert = 'Please specify your relationship.');
      return;
    }
    _run(() async {
      final msg = await LovedOnesService.joinLovedOne(
        deviceId: _lookup!.deviceId,
        relationship: _joinRelationship!,
        relationshipOther: _joinOtherCtrl.text,
      );
      _doneMessage = msg;
      _show(_Pane.done);
    });
  }

  // ---------- step 2b ----------
  void _add() {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _alert = 'Enter the full name of your loved one.');
      return;
    }
    if (_relationship == null) {
      setState(() => _alert = 'Choose how you are related to them.');
      return;
    }
    if (_relationship == 'Other' && _relOtherCtrl.text.trim().isEmpty) {
      setState(() => _alert = 'Please specify your relationship.');
      return;
    }
    if (_barangay == null) {
      setState(() => _alert = 'Select the barangay from the list.');
      return;
    }
    _run(() async {
      final msg = await LovedOnesService.addLovedOne(
        fullName: _nameCtrl.text,
        relationship: _relationship!,
        relationshipOther: _relOtherCtrl.text,
        dateOfBirth: _dob ?? '',
        occupation: _occupationCtrl.text,
        houseNo: _houseCtrl.text,
        street: _streetCtrl.text,
        barangay: _barangay!,
        city: _cityCtrl.text,
        province: _provinceCtrl.text,
        zipCode: _zipCtrl.text,
        deviceId: _lookup?.deviceId ?? '',
      );
      _doneMessage = msg;
      _show(_Pane.done);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _pane != _Pane.done,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _pane == _Pane.done) Navigator.pop(context, true);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: const MinimalBackAppBar(title: 'Add a loved one'),
        body: SafeArea(
          top: false,
          child: ResponsiveContent(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              children: [
                _StepsRow(pane: _pane),
                const SizedBox(height: 20),
                if (_alert != null) ...[
                  _AlertBox(text: _alert!),
                  const SizedBox(height: 14),
                ],
                ...switch (_pane) {
                  _Pane.device => _devicePane(),
                  _Pane.existing => _existingPane(),
                  _Pane.newOne => _newPane(),
                  _Pane.done => _donePane(),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _title(String title, String sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(sub, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 18),
      ],
    );
  }

  List<Widget> _devicePane() => [
        _title(
          'Enter the Device ID',
          "You'll find it on the sticker under the ALISTO device, next to "
              'its QR code.',
        ),
        AppTextField(
          label: 'Device ID',
          hint: 'e.g. ALISTO-0001',
          controller: _deviceCtrl,
          suffixIcon: IconButton(
            tooltip: 'Scan the QR code',
            icon: const Icon(Icons.qr_code_scanner_rounded),
            onPressed: _busy ? null : _scan,
          ),
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: 'Continue',
          loading: _busy,
          onPressed: _checkDevice,
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _busy
                ? null
                : () {
                    _lookup = null;
                    _show(_Pane.newOne);
                  },
            child: const Text("I don't have the device with me yet"),
          ),
        ),
      ];

  List<Widget> _existingPane() {
    final l = _lookup!;
    final born =
        (l.elderDob ?? '').isNotEmpty ? 'Born ${l.elderDob} · ' : '';
    return [
      _title(
        'This device already has an owner',
        "Another family member set it up. Confirm it's your loved one to "
            'link them to your account.',
      ),
      AppCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            LovedOneAvatar(initials: l.elderInitials ?? '?', size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.elderName ?? '—',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    '${born}Device ${l.deviceId} · ${l.familyCount} of '
                    '${l.familyLimit} family members linked',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Row(
                    children: [
                      Icon(Icons.verified_rounded,
                          size: 13, color: Colors.green),
                      SizedBox(width: 4),
                      Text(
                        'Verified device',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      LabeledDropdown<String>(
        label: 'Your relationship to them',
        hint: 'Select relationship',
        value: _joinRelationship,
        items: relationshipItems(),
        onChanged: (v) => setState(() => _joinRelationship = v),
      ),
      if (_joinRelationship == 'Other') ...[
        const SizedBox(height: 14),
        AppTextField(
          label: 'Please specify',
          hint: 'e.g. Niece',
          controller: _joinOtherCtrl,
        ),
      ],
      const SizedBox(height: 22),
      PrimaryButton(
        label: 'Add to my loved ones',
        loading: _busy,
        onPressed: _join,
      ),
      const SizedBox(height: 8),
      Center(
        child: TextButton(
          onPressed: _busy ? null : () => _show(_Pane.device),
          child: const Text('Back'),
        ),
      ),
    ];
  }

  List<Widget> _newPane() => [
        _title(
          'Tell us about your loved one',
          "This is how they'll appear to you and to your barangay health "
              'worker.',
        ),
        if (_lookup != null) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.memory_rounded,
                      size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Device ${_lookup!.deviceId}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
        const LoGroupLabel('Personal information'),
        AppTextField(
          label: 'Full name',
          hint: 'Juan Dela Cruz',
          controller: _nameCtrl,
        ),
        const SizedBox(height: 14),
        DobPickerField(
          label: 'Date of birth',
          value: _dob,
          onChanged: (v) => setState(() => _dob = v),
        ),
        const SizedBox(height: 14),
        LabeledDropdown<String>(
          label: 'Relationship',
          value: _relationship,
          items: relationshipItems(),
          onChanged: (v) => setState(() => _relationship = v),
        ),
        if (_relationship == 'Other') ...[
          const SizedBox(height: 14),
          AppTextField(
            label: 'Please specify',
            hint: 'e.g. Niece',
            controller: _relOtherCtrl,
          ),
        ],
        const SizedBox(height: 14),
        AppTextField(
          label: 'Occupation (optional)',
          hint: 'e.g. Retired teacher',
          controller: _occupationCtrl,
        ),
        const LoGroupLabel('Home address'),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                label: 'House / unit no.',
                hint: '123',
                controller: _houseCtrl,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                label: 'Street',
                hint: 'Mahogany St.',
                controller: _streetCtrl,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LabeledDropdown<String>(
          label: 'Barangay',
          hint: 'Select barangay',
          value: _barangay,
          items: [
            for (final b in kCebuCityBarangays)
              DropdownMenuItem(value: b, child: Text(b)),
          ],
          onChanged: (v) => setState(() => _barangay = v),
        ),
        const SizedBox(height: 14),
        AppTextField(
          label: 'City / municipality',
          hint: 'Cebu City',
          controller: _cityCtrl,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                label: 'Province',
                hint: 'Cebu',
                controller: _provinceCtrl,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                label: 'ZIP code',
                hint: '6000',
                keyboardType: TextInputType.number,
                controller: _zipCtrl,
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        PrimaryButton(
          label: 'Add loved one',
          loading: _busy,
          onPressed: _add,
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _busy ? null : () => _show(_Pane.device),
            child: const Text('Back'),
          ),
        ),
      ];

  List<Widget> _donePane() => [
        const SizedBox(height: 20),
        Center(
          child: Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded,
                size: 40, color: Colors.green),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          _doneMessage.isEmpty ? 'Added' : _doneMessage,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          'Next, open their details to add the emergency contacts the device '
          'will text.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 26),
        PrimaryButton(
          label: 'Done',
          onPressed: () => Navigator.pop(context, true),
        ),
      ];
}

/// Device -> Loved one -> Done, like the web's left rail.
class _StepsRow extends StatelessWidget {
  final _Pane pane;
  const _StepsRow({required this.pane});

  @override
  Widget build(BuildContext context) {
    final current = switch (pane) {
      _Pane.device => 0,
      _Pane.existing || _Pane.newOne => 1,
      _Pane.done => 2,
    };
    const labels = ['Device', 'Loved one', 'Done'];
    return Row(
      children: [
        for (var i = 0; i < 3; i++) ...[
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: i <= current ? AppColors.primary : AppColors.border,
              shape: BoxShape.circle,
            ),
            child: i < current
                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                : Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: i <= current
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                  ),
          ),
          const SizedBox(width: 6),
          Text(
            labels[i],
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: i == current ? FontWeight.w700 : FontWeight.w500,
              color: i == current
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
            ),
          ),
          if (i < 2)
            const Expanded(
              child: Divider(indent: 8, endIndent: 8, thickness: 1),
            ),
        ],
      ],
    );
  }
}

class _AlertBox extends StatelessWidget {
  final String text;
  const _AlertBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withOpacity(0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}
