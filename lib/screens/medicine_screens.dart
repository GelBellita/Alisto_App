import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' as cupertino;

import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/firestore_service.dart';
import '../models/app_models.dart';

// =========================================================
// SHARED ADD / EDIT SHEET
// =========================================================
/// Opens the medicine reminder sheet.
/// Pass [existing] to edit that reminder, or leave it null to add a new one.
Future<void> showMedicineSheet(
  BuildContext context, {
  MedicineModel? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      top: false,
      child: _MedicineSheet(existing: existing),
    ),
  );
}

/// Formats a TimeOfDay as "9:00 AM" — single time, no range, no manual
/// AM/PM typing needed since it always comes from the picker.
String _formatTimeOfDay(TimeOfDay t) {
  final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
  final minute = t.minute.toString().padLeft(2, '0');
  final period = t.period == DayPeriod.am ? 'AM' : 'PM';
  return '$hour:$minute $period';
}

/// Best-effort parse of whatever time string was already saved (old data
/// may still be in the "9:00 - 10:00 AM" range format), so editing an
/// existing reminder pre-fills the picker instead of showing blank.
TimeOfDay? _parseTimeString(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final match = RegExp(r'(\d{1,2}):(\d{2})\s*([AaPp][Mm])').firstMatch(raw);
  if (match == null) return null;
  int hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  final period = match.group(3)!.toUpperCase();
  if (period == 'PM' && hour != 12) hour += 12;
  if (period == 'AM' && hour == 12) hour = 0;
  return TimeOfDay(hour: hour, minute: minute);
}

class _MedicineSheet extends StatefulWidget {
  final MedicineModel? existing;
  const _MedicineSheet({this.existing});

  @override
  State<_MedicineSheet> createState() => _MedicineSheetState();
}

const List<int> _kHourIntervalOptions = [4, 6, 8, 12];
const List<int> _kDayIntervalOptions = [2, 3, 7];

class _MedicineSheetState extends State<_MedicineSheet> {
  late final TextEditingController _nameController;
  TimeOfDay? _selectedTime;
  bool _saving = false;

  // 'daily' | 'every_hours' | 'every_days' -- see MedicineModel's doc
  // comment for what each means and how the device schedules around it.
  late String _scheduleType;
  late int _intervalValue;

  // Shown inline in the sheet's own layout rather than via a SnackBar --
  // a SnackBar attached to the app's root ScaffoldMessenger renders
  // BEHIND an open modal bottom sheet (the sheet sits in its own overlay
  // entry above the Scaffold), so it was silently invisible the whole
  // time this sheet stayed open.
  String? _errorMessage;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _selectedTime = _parseTimeString(widget.existing?.time);
    _scheduleType = widget.existing?.scheduleType ?? 'daily';
    _intervalValue = widget.existing?.intervalValue ??
        (_scheduleType == 'every_days' ? _kDayIntervalOptions.first : _kHourIntervalOptions.first);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    setState(() => _errorMessage = message);
  }

  Future<void> _pickTime() async {
    final initial = _selectedTime ?? TimeOfDay.now();
    var tempDateTime = DateTime(2020, 1, 1, initial.hour, initial.minute);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: SizedBox(
            height: 280,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedTime = TimeOfDay(
                            hour: tempDateTime.hour,
                            minute: tempDateTime.minute,
                          );
                        });
                        Navigator.pop(sheetContext);
                      },
                      child: const Text(
                        'Done',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 1, color: AppColors.border),
                Expanded(
                  child: cupertino.CupertinoDatePicker(
                    mode: cupertino.CupertinoDatePickerMode.time,
                    initialDateTime: tempDateTime,
                    use24hFormat: false,
                    onDateTimeChanged: (value) => tempDateTime = value,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Shows a "double-check before saving" summary of exactly what will be
  /// scheduled -- this drives real spoken reminders on the device (see
  /// alisto_main.py's medicine_reminder_loop()), so a typo or wrong
  /// interval here means a real medicine actually gets mis-timed or
  /// missed, not just a cosmetic mistake. Returns true only if the user
  /// explicitly confirms; false (including dialog dismissal) means "go
  /// back and let me fix it."
  Future<bool> _confirmBeforeSave(String name, String time) async {
    final preview = MedicineModel(
      id: '',
      name: name,
      time: time,
      status: 'Upcoming',
      scheduleType: _scheduleType,
      intervalValue: _scheduleType == 'daily' ? null : _intervalValue,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 28, offset: Offset(0, 10)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.medication_rounded,
                  color: AppColors.primary,
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Review before saving',
                textAlign: TextAlign.center,
                style: Theme.of(dialogContext).textTheme.titleMedium
                    ?.copyWith(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'This is what the device will actually speak as a reminder. '
                'Double-check it\'s correct.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preview.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded, size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          preview.scheduleLabel,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Edit', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Confirm & Save',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return confirmed == true;
  }

  Future<void> _handleSave() async {
    setState(() => _errorMessage = null);
    final name = _nameController.text.trim();
    if (name.isEmpty || _selectedTime == null) {
      _showError('Please fill in the medicine name and select a time.');
      return;
    }
    final time = _formatTimeOfDay(_selectedTime!);

    // Block a second active reminder for the same medicine outright --
    // see FirestoreService.hasActiveMedicineNamed()'s doc comment for
    // why this isn't just a warning: the correct way to schedule
    // multiple doses of the SAME medicine is 'Every X hrs' on one
    // entry, not two separate entries that could double-announce/
    // double-mark it.
    setState(() => _saving = true);
    bool duplicate;
    try {
      duplicate = await FirestoreService.hasActiveMedicineNamed(
        name,
        excludeId: widget.existing?.id,
      );
    } catch (e) {
      duplicate = false; // best-effort check -- never block saving over this
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (duplicate) {
      _showError(
        'There\'s already an active reminder for "$name". Please edit '
        'that one instead of adding a new one.',
      );
      return;
    }

    if (!await _confirmBeforeSave(name, time)) return;
    if (!mounted) return;

    // Only 'every_days' needs an anchor date to count "every Nth day"
    // from. Preserve the original start_date when editing an existing
    // 'every_days' reminder (re-picking today's date on every edit would
    // reset which days it falls on); otherwise anchor it to today.
    String? startDate;
    if (_scheduleType == 'every_days') {
      startDate = widget.existing?.scheduleType == 'every_days'
          ? widget.existing?.startDate
          : null;
      startDate ??= DateTime.now().toIso8601String().substring(0, 10);
    }
    final intervalValue = _scheduleType == 'daily' ? null : _intervalValue;

    setState(() => _saving = true);
    try {
      if (_isEditing) {
        await FirestoreService.updateMedicine(
          medicineId: widget.existing!.id,
          name: name,
          time: time,
          scheduleType: _scheduleType,
          intervalValue: intervalValue,
          startDate: startDate,
        );
      } else {
        await FirestoreService.addMedicine(
          name: name,
          time: time,
          scheduleType: _scheduleType,
          intervalValue: intervalValue,
          startDate: startDate,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showError('Could not save the reminder. Please try again.');
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete reminder?'),
        content: Text(
          'This will remove the reminder for '
          '${widget.existing!.name}.',
          style: Theme.of(dialogContext).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => _saving = true);
    try {
      await FirestoreService.deleteMedicine(widget.existing!.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showError('Could not delete the reminder.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _isEditing
                      ? 'Edit Medicine Reminder'
                      : 'Add Medicine Reminder',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (_isEditing)
                IconButton(
                  tooltip: 'Delete',
                  onPressed: _saving ? null : _handleDelete,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          AppTextField(
            label: 'Medicine Name',
            controller: _nameController,
          ),
          const SizedBox(height: 14),
          Text('Repeats', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              _ScheduleTypeChip(
                label: 'Once daily',
                selected: _scheduleType == 'daily',
                onTap: () => setState(() => _scheduleType = 'daily'),
              ),
              const SizedBox(width: 8),
              _ScheduleTypeChip(
                label: 'Every X hrs',
                selected: _scheduleType == 'every_hours',
                onTap: () => setState(() {
                  _scheduleType = 'every_hours';
                  if (!_kHourIntervalOptions.contains(_intervalValue)) {
                    _intervalValue = _kHourIntervalOptions.first;
                  }
                }),
              ),
              const SizedBox(width: 8),
              _ScheduleTypeChip(
                label: 'Every X days',
                selected: _scheduleType == 'every_days',
                onTap: () => setState(() {
                  _scheduleType = 'every_days';
                  if (!_kDayIntervalOptions.contains(_intervalValue)) {
                    _intervalValue = _kDayIntervalOptions.first;
                  }
                }),
              ),
            ],
          ),
          if (_scheduleType == 'every_hours') ...[
            const SizedBox(height: 12),
            _IntervalChipsRow(
              options: _kHourIntervalOptions,
              suffix: 'hrs',
              selected: _intervalValue,
              onSelected: (v) => setState(() => _intervalValue = v),
            ),
          ] else if (_scheduleType == 'every_days') ...[
            const SizedBox(height: 12),
            _IntervalChipsRow(
              options: _kDayIntervalOptions,
              suffix: 'days',
              selected: _intervalValue,
              onSelected: (v) => setState(() => _intervalValue = v),
            ),
          ],
          const SizedBox(height: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _scheduleType == 'every_hours' ? 'Start Time' : 'Time',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _pickTime,
                child: InputDecorator(
                  decoration: const InputDecoration(),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedTime == null
                            ? 'Select time'
                            : _formatTimeOfDay(_selectedTime!),
                        style: TextStyle(
                          color: _selectedTime == null
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                        ),
                      ),
                      const Icon(
                        Icons.access_time_rounded,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(fontSize: 12, color: AppColors.error, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          PrimaryButton(
            label: _isEditing ? 'Save Changes' : 'Save Reminder',
            loading: _saving,
            onPressed: _handleSave,
          ),
        ],
      ),
    );
  }
}

class _ScheduleTypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ScheduleTypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _IntervalChipsRow extends StatelessWidget {
  final List<int> options;
  final String suffix;
  final int selected;
  final ValueChanged<int> onSelected;
  const _IntervalChipsRow({
    required this.options,
    required this.suffix,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          GestureDetector(
            onTap: () => onSelected(option),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected == option ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected == option ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Text(
                '$option $suffix',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected == option ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// =========================================================
// ALL MEDICINE REMINDERS SCREEN
// =========================================================
class AllMedicinesScreen extends StatelessWidget {
  const AllMedicinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const MinimalBackAppBar(),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => showMedicineSheet(context),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: SafeArea(
        top: false,
        child: ResponsiveContent(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Medicine Reminders',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap a reminder to edit it.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<dynamic>(
                    stream: FirestoreService.medicinesStream(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              'Could not load reminders: ${snapshot.error}',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.error),
                            ),
                          ),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(
                          child: SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }

                      final docs = snapshot.data;
                      if (docs.isEmpty) {
                        return _EmptyReminders(
                          onAdd: () => showMedicineSheet(context),
                        );
                      }

                      final medicines = docs
                          .map<MedicineModel>((d) => MedicineModel.fromDoc(d))
                          .toList();

                      return RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: () => Future.delayed(const Duration(milliseconds: 600)),
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: medicines.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) =>
                              _MedicineListTile(medicine: medicines[index]),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyReminders extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyReminders({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.medication_rounded,
            size: 54,
            color: AppColors.primary.withOpacity(0.35),
          ),
          const SizedBox(height: 12),
          Text(
            'No reminders yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Add the first medicine schedule to get started.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: 220,
            child: PrimaryButton(label: 'Add Medicine', onPressed: onAdd),
          ),
        ],
      ),
    );
  }
}

class _MedicineListTile extends StatelessWidget {
  final MedicineModel medicine;
  const _MedicineListTile({required this.medicine});

  @override
  Widget build(BuildContext context) {
    final notified = medicine.status == 'Notified';
    final statusColor = notified ? AppColors.primary : AppColors.textSecondary;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => showMedicineSheet(context, existing: medicine),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.medication_rounded,
                size: 19,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    medicine.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  Text(
                    medicine.scheduleLabel,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            StatusPill(label: medicine.status, color: statusColor),
            const SizedBox(width: 6),
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