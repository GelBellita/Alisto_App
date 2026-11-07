import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/loved_one_models.dart';
import '../services/loved_ones_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/loved_one_widgets.dart';
import 'qr_scanner_screen.dart';

// =========================================================
// LOVED ONE DETAILS — the web's "Loved one details" window:
//   left  : photo, name, relationship, status, personal info, ALISTO
//           device (with "Link an ALISTO device" when none)
//   right : emergency contacts (add / edit / remove) + barangay health
//           worker(s) for their barangay, with "Add as contact"
//   footer: Delete loved one · Edit / Save
// =========================================================
class LovedOneDetailsScreen extends StatefulWidget {
  final String elderId;
  final LovedOne? initial;

  /// Called after an edit, photo, or device link, so the list knows to
  /// re-read this card (and skips the re-read when nothing changed).
  final VoidCallback? onChanged;
  const LovedOneDetailsScreen({
    super.key,
    required this.elderId,
    this.initial,
    this.onChanged,
  });

  @override
  State<LovedOneDetailsScreen> createState() => _LovedOneDetailsScreenState();
}

class _LovedOneDetailsScreenState extends State<LovedOneDetailsScreen> {
  LovedOne? _e;
  List<EmergencyContact>? _contacts;
  List<BhwInfo> _bhws = const [];
  String? _contactsError;

  bool _editing = false;
  bool _saving = false;
  bool _photoBusy = false;
  bool _linking = false;

  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _linkCtrl = TextEditingController();
  String? _relEdit;
  String? _dobEdit;

  @override
  void initState() {
    super.initState();
    _e = widget.initial;
    // The card already has everything except the contacts -- don't
    // re-read the whole snapshot just to open the screen.
    if (_e == null) {
      _load();
    } else {
      _loadContacts();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _linkCtrl.dispose();
    super.dispose();
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.error : null,
      ),
    );
  }

  /// One confirm dialog for every destructive action on this screen.
  Future<bool> _confirm(String title, String body, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action, style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  String _err(Object e) =>
      e is LovedOneException ? e.message : 'Something went wrong. Try again.';

  Future<void> _load() async {
    try {
      final e = await LovedOnesService.loadLovedOne(widget.elderId);
      if (mounted) setState(() => _e = e);
    } catch (e) {
      _toast(_err(e), error: true);
      if (e is LovedOneException && mounted) Navigator.pop(context);
      return;
    }
    await _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      final (contacts, bhws) = await LovedOnesService.loadContacts(
        widget.elderId,
      );
      if (!mounted) return;
      setState(() {
        _contacts = contacts;
        _bhws = bhws;
        _contactsError = null;
      });
    } catch (e) {
      if (mounted) setState(() => _contactsError = _err(e));
    }
  }

  // ---------- edit ----------
  void _startEdit() {
    final e = _e;
    if (e == null) return;
    _nameCtrl.text = e.name;
    _addressCtrl.text = e.address ?? '';
    setState(() {
      _relEdit = e.relationship.isEmpty ? 'Son/Daughter' : e.relationship;
      _dobEdit = e.dateOfBirth;
      _editing = true;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final msg = await LovedOnesService.updateLovedOne(
        elderId: widget.elderId,
        fullName: _nameCtrl.text,
        relationship: _relEdit ?? '',
        dateOfBirth: _dobEdit ?? '',
        address: _addressCtrl.text,
      );
      _toast(msg);
      widget.onChanged?.call();
      setState(() => _editing = false);
      await _load();
    } catch (e) {
      _toast(_err(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---------- photo ----------
  Future<void> _changePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.background,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 70,
      );
      if (picked == null) return;
      setState(() => _photoBusy = true);
      final bytes = await picked.readAsBytes();
      final lower = picked.name.toLowerCase();
      final mime = lower.endsWith('.png')
          ? 'image/png'
          : lower.endsWith('.webp')
          ? 'image/webp'
          : 'image/jpeg';
      await LovedOnesService.uploadPhoto(widget.elderId, bytes, mime);
      _toast('Photo updated.');
      widget.onChanged?.call();
      await _load();
    } catch (e) {
      _toast(_err(e), error: true);
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  // ---------- device ----------
  Future<void> _scanForLink() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (code == null || !mounted) return;
    _linkCtrl.text = code;
    _linkDevice();
  }

  Future<void> _linkDevice() async {
    setState(() => _linking = true);
    try {
      final msg = await LovedOnesService.linkDevice(
        widget.elderId,
        _linkCtrl.text,
      );
      _linkCtrl.clear();
      _toast(msg);
      widget.onChanged?.call();
      await _load();
    } catch (e) {
      _toast(_err(e), error: true);
    } finally {
      if (mounted) setState(() => _linking = false);
    }
  }

  // ---------- delete loved one ----------
  Future<void> _confirmDelete() async {
    final name = _e?.name ?? 'this person';
    final ok = await _confirm(
      'Delete this loved one?',
      '$name will be removed from your account. If other family members '
          'are linked, they keep access. If you are the last one, the '
          'profile is deleted and the ALISTO device is unlinked.',
      'Delete',
    );
    if (!ok) return;
    setState(() => _saving = true);
    try {
      final msg = await LovedOnesService.deleteLovedOne(widget.elderId);
      _toast(msg);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _toast(_err(e), error: true);
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---------- contacts ----------
  Future<void> _removeContact(EmergencyContact c) async {
    final ok = await _confirm(
      'Remove ${c.fullName}?',
      'The ALISTO device will stop texting this number during an emergency.',
      'Remove',
    );
    if (!ok) return;
    try {
      _toast(
        await LovedOnesService.deleteContact(
          elderId: widget.elderId,
          contactId: c.id,
        ),
      );
      await _loadContacts();
    } catch (e) {
      _toast(_err(e), error: true);
    }
  }

  Future<void> _openContactForm({
    EmergencyContact? existing,
    Map<String, String>? prefill,
  }) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ContactFormSheet(
        elderId: widget.elderId,
        existing: existing,
        prefill: prefill,
      ),
    );
    if (saved == true) await _loadContacts();
  }

  // =========================================================
  @override
  Widget build(BuildContext context) {
    final e = _e;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const MinimalBackAppBar(title: 'Loved One Details'),
      body: e == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: ResponsiveContent(
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    _hero(e),
                    const LoGroupLabel('Personal information'),
                    _personalInfo(e),
                    const LoGroupLabel('ALISTO device'),
                    _device(e),
                    const LoGroupLabel('Emergency contacts'),
                    _contactsSection(),
                    const LoGroupLabel('Barangay health worker'),
                    _bhwSection(),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: e == null ? null : _footer(),
    );
  }

  Widget _hero(LovedOne e) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              LovedOneAvatar(
                initials: e.initials,
                photoUrl: e.photoUrl,
                size: 72,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Material(
                  color: AppColors.primary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _photoBusy ? null : _changePhoto,
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: _photoBusy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.photo_camera_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _editing
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppTextField(label: 'Full name', controller: _nameCtrl),
                      const SizedBox(height: 12),
                      LabeledDropdown<String>(
                        label: 'Relationship',
                        value: _relEdit,
                        items: relationshipItems(extra: _relEdit),
                        onChanged: (v) => setState(() => _relEdit = v),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        e.relationship,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LovedOneStatusPill(lovedOne: e),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _personalInfo(LovedOne e) {
    if (_editing) {
      return AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            DobPickerField(
              label: 'Date of birth',
              value: _dobEdit,
              onChanged: (v) => setState(() => _dobEdit = v),
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Address',
              hint: 'Full address',
              controller: _addressCtrl,
            ),
          ],
        ),
      );
    }
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _Row(
            'Date of birth',
            (e.dateOfBirth ?? '').isEmpty ? '—' : e.dateOfBirth!,
          ),
          const AppDivider(),
          _Row(
            'Address',
            (e.address ?? '').isEmpty ? '—' : e.address!,
            stack: true,
          ),
        ],
      ),
    );
  }

  Widget _device(LovedOne e) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _Row('Device ID', e.deviceId ?? '—'),
          if (e.deviceId == null) ...[
            const AppDivider(),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Link an ALISTO device',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _linkCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            hintText: 'Serial number on the device',
                            isDense: true,
                            suffixIcon: IconButton(
                              icon: const Icon(
                                Icons.qr_code_scanner_rounded,
                                size: 20,
                              ),
                              onPressed: _linking ? null : _scanForLink,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                        onPressed: _linking ? null : _linkDevice,
                        child: _linking
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Link'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const AppDivider(),
          _Row('Status', e.deviceStatus, note: e.deviceNote, stack: true),
          const AppDivider(),
          _Row('Last check-in', e.lastCheckin),
          const AppDivider(),
          _Row('Next reminder', e.nextMedicine),
          const AppDivider(),
          _Row('Location', e.location, stack: true),
        ],
      ),
    );
  }

  Widget _contactsSection() {
    final contacts = _contacts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'The ALISTO device sends an SMS to everyone on this list during an '
          'emergency.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: _contactsError != null
              ? Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    _contactsError!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                )
              : contacts == null
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: Text(
                    'Loading contacts...',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : contacts.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: Accent.yellow,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No emergency contacts yet. Add at least '
                          'one so the device has someone to text.',
                          style: TextStyle(fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < contacts.length; i++) ...[
                      _ContactTile(
                        contact: contacts[i],
                        onEdit: () => _openContactForm(existing: contacts[i]),
                        onRemove: () => _removeContact(contacts[i]),
                      ),
                      if (i != contacts.length - 1) const AppDivider(),
                    ],
                  ],
                ),
        ),
        if (contacts != null &&
            contacts.length < LovedOnesService.maxContactsPerElder) ...[
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: () => _openContactForm(),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text('Add contact'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _bhwSection() {
    final numbers = (_contacts ?? []).map((c) => c.contactNum).toSet();
    final canAdd =
        (_contacts?.length ?? 0) < LovedOnesService.maxContactsPerElder;
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: _bhws.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'No approved barangay health worker is assigned to this '
                'address yet.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < _bhws.length; i++) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        InitialsAvatar(
                          initials: initialsOf(_bhws[i].fullName),
                          color: Accent.green,
                          size: 40,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _bhws[i].fullName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                ),
                              ),
                              Text(
                                [
                                  [
                                    'BHW, ${_bhws[i].barangay}',
                                    _bhws[i].healthCenter,
                                  ].where((s) => s.isNotEmpty).join(' · '),
                                  _bhws[i].contactNum,
                                ].where((s) => s.isNotEmpty).join(' · '),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_bhws[i].contactNum.isNotEmpty &&
                            numbers.contains(
                              LovedOnesService.cleanPhMobile(
                                    _bhws[i].contactNum,
                                  ) ??
                                  _bhws[i].contactNum,
                            ))
                          const Text(
                            'In contacts',
                            style: TextStyle(
                              fontSize: 11,
                              color: Accent.green,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        else if (_bhws[i].contactNum.isNotEmpty && canAdd)
                          TextButton(
                            onPressed: () => _openContactForm(
                              prefill: {
                                'full_name': _bhws[i].fullName,
                                'relationship': 'Barangay health worker',
                                'contact_num': _bhws[i].contactNum,
                                'contact_type': 'BHW',
                              },
                            ),
                            child: const Text(
                              'Add as contact',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (i != _bhws.length - 1) const AppDivider(),
                ],
              ],
            ),
    );
  }

  Widget _footer() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            if (!_editing)
              TextButton.icon(
                onPressed: _saving ? null : _confirmDelete,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                  size: 18,
                ),
                label: const Text(
                  'Delete loved one',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            const Spacer(),
            if (_editing)
              TextButton(
                onPressed: _saving
                    ? null
                    : () => setState(() => _editing = false),
                child: const Text('Cancel'),
              ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: const StadiumBorder(),
              ),
              onPressed: _saving ? null : (_editing ? _save : _startEdit),
              child: _saving && _editing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_editing ? 'Save' : 'Edit'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Label / value row, like the web's .lo-row.
class _Row extends StatelessWidget {
  final String label;
  final String value;
  final String? note;
  final bool stack;
  const _Row(this.label, this.value, {this.note, this.stack = false});

  @override
  Widget build(BuildContext context) {
    const labelStyle = TextStyle(fontSize: 12, color: AppColors.textSecondary);
    const valueStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w700);
    final noteWidget = (note ?? '').isEmpty
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              note!,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: stack
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: labelStyle),
                const SizedBox(height: 2),
                Text(value, style: valueStyle),
                if (noteWidget != null) noteWidget,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: labelStyle),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    style: valueStyle,
                  ),
                ),
              ],
            ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final EmergencyContact contact;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  const _ContactTile({
    required this.contact,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final c = contact;
    final chipColor = switch (c.contactType) {
      'FAMILY' => Accent.purple,
      'BHW' => Accent.green,
      _ => AppColors.textSecondary,
    };
    final meta = [
      c.relationship,
      c.contactNum,
      c.emailAdd,
    ].where((s) => s.isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          InitialsAvatar(
            initials: initialsOf(c.fullName),
            color: chipColor,
            size: 40,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        c.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: chipColor.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        c.typeLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: chipColor,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  meta,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit ${c.fullName}',
            icon: const Icon(
              Icons.edit_outlined,
              size: 19,
              color: AppColors.textSecondary,
            ),
            onPressed: onEdit,
          ),
          IconButton(
            tooltip: 'Remove ${c.fullName}',
            icon: const Icon(
              Icons.delete_outline_rounded,
              size: 19,
              color: AppColors.error,
            ),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

/// Add / edit contact — same fields as the web's ec-form.
class _ContactFormSheet extends StatefulWidget {
  final String elderId;
  final EmergencyContact? existing;
  final Map<String, String>? prefill;
  const _ContactFormSheet({required this.elderId, this.existing, this.prefill});

  @override
  State<_ContactFormSheet> createState() => _ContactFormSheetState();
}

class _ContactFormSheetState extends State<_ContactFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _rel;
  late final TextEditingController _num;
  late final TextEditingController _email;
  late String _type;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    final p = widget.prefill ?? const {};
    _name = TextEditingController(text: c?.fullName ?? p['full_name'] ?? '');
    _rel = TextEditingController(
      text: c?.relationship ?? p['relationship'] ?? '',
    );
    _num = TextEditingController(text: c?.contactNum ?? p['contact_num'] ?? '');
    _email = TextEditingController(text: c?.emailAdd ?? '');
    _type = c?.contactType ?? p['contact_type'] ?? 'FAMILY';
  }

  @override
  void dispose() {
    _name.dispose();
    _rel.dispose();
    _num.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final c = widget.existing;
      if (c == null) {
        await LovedOnesService.addContact(
          elderId: widget.elderId,
          fullName: _name.text,
          relationship: _rel.text,
          contactNum: _num.text,
          emailAdd: _email.text,
          contactType: _type,
        );
      } else {
        await LovedOnesService.updateContact(
          elderId: widget.elderId,
          contactId: c.id,
          fullName: _name.text,
          relationship: _rel.text,
          contactNum: _num.text,
          emailAdd: _email.text,
          contactType: _type,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on LovedOneException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.existing == null ? 'Add contact' : 'Edit contact',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: AppColors.error)),
              ],
              const SizedBox(height: 16),
              AppTextField(label: 'Full name', controller: _name),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Relationship',
                hint: 'e.g. Son, Neighbor',
                controller: _rel,
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Mobile number',
                hint: '09171234567',
                keyboardType: TextInputType.phone,
                controller: _num,
              ),
              const SizedBox(height: 14),
              LabeledDropdown<String>(
                label: 'Type',
                value: _type,
                items: const [
                  DropdownMenuItem(value: 'FAMILY', child: Text('Family')),
                  DropdownMenuItem(
                    value: 'BHW',
                    child: Text('Barangay health worker'),
                  ),
                  DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                ],
                onChanged: (v) => setState(() => _type = v ?? 'OTHER'),
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Email (optional)',
                keyboardType: TextInputType.emailAddress,
                controller: _email,
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Save contact',
                loading: _saving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
