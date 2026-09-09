import 'package:flutter/material.dart';

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
    builder: (sheetContext) => _MedicineSheet(existing: existing),
  );
}

class _MedicineSheet extends StatefulWidget {
  final MedicineModel? existing;
  const _MedicineSheet({this.existing});

  @override
  State<_MedicineSheet> createState() => _MedicineSheetState();
}

class _MedicineSheetState extends State<_MedicineSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _timeController;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _timeController = TextEditingController(text: widget.existing?.time ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    final time = _timeController.text.trim();
    if (name.isEmpty || time.isEmpty) {
      _showError('Please fill in both fields.');
      return;
    }

    setState(() => _saving = true);
    try {
      if (_isEditing) {
        await FirestoreService.updateMedicine(
          medicineId: widget.existing!.id,
          name: name,
          time: time,
        );
      } else {
        await FirestoreService.addMedicine(name: name, time: time);
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
            hint: 'e.g. Losartan',
            controller: _nameController,
          ),
          const SizedBox(height: 14),
          AppTextField(
            label: 'Time',
            hint: 'e.g. 09:00 - 10:00 AM',
            controller: _timeController,
          ),
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
                          child: Text(
                            'Could not load reminders.',
                            style: Theme.of(context).textTheme.bodyMedium,
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

                      final docs = snapshot.data.docs;
                      if (docs.isEmpty) {
                        return _EmptyReminders(
                          onAdd: () => showMedicineSheet(context),
                        );
                      }

                      final medicines = docs
                          .map<MedicineModel>((d) => MedicineModel.fromDoc(d))
                          .toList();

                      return ListView.separated(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: medicines.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) =>
                            _MedicineListTile(medicine: medicines[index]),
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
                    medicine.time,
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
