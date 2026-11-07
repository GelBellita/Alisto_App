import 'package:flutter/material.dart';

import '../models/loved_one_models.dart';
import '../theme/app_theme.dart';
import 'common_widgets.dart';

/// Photo (from elder_profile.photo_url), or the shared InitialsAvatar.
class LovedOneAvatar extends StatelessWidget {
  final String initials;
  final String? photoUrl;
  final double size;
  const LovedOneAvatar({
    super.key,
    required this.initials,
    this.photoUrl,
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) {
    final bytes = decodeDataUrl(photoUrl);
    if (bytes == null) {
      return InitialsAvatar(
        initials: initials,
        color: AppColors.primary,
        size: size,
      );
    }
    return ClipOval(
      child: Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      ),
    );
  }
}

/// The web's card status (Emergency / Online / Offline / No Device…),
/// drawn with the shared StatusPill.
class LovedOneStatusPill extends StatelessWidget {
  final LovedOne lovedOne;
  const LovedOneStatusPill({super.key, required this.lovedOne});

  @override
  Widget build(BuildContext context) {
    final e = lovedOne;
    final color = e.isEmergency
        ? AppColors.error
        : switch (e.status) {
            LovedOneStatus.online => Accent.green,
            LovedOneStatus.offline => AppColors.textSecondary,
            LovedOneStatus.attention => Accent.yellow,
          };
    return StatusPill(label: e.statusLabel, color: color);
  }
}

/// Section heading with the spacing the details/add screens use.
class LoGroupLabel extends StatelessWidget {
  final String text;
  const LoGroupLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: SectionLabel(text),
    );
  }
}

/// Label above a dropdown — same look as the app's other form fields.
class LabeledDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  const LabeledDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint = 'Select',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          value: value,
          isExpanded: true,
          hint: Text(hint),
          items: items,
          onChanged: onChanged,
          decoration: const InputDecoration(),
        ),
      ],
    );
  }
}

/// Date picker field that returns "YYYY-MM-DD" (what the web stores).
class DobPickerField extends StatelessWidget {
  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;
  const DobPickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(value ?? '') ?? DateTime(1950, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked == null) return;
    String two(int n) => n.toString().padLeft(2, '0');
    onChanged('${picked.year}-${two(picked.month)}-${two(picked.day)}');
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _pick(context),
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: InputDecoration(
              suffixIcon: hasValue
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => onChanged(null),
                    )
                  : const Icon(Icons.calendar_today_rounded, size: 18),
            ),
            child: Text(
              hasValue ? value! : 'Select date',
              style: TextStyle(
                fontSize: 14,
                color: hasValue
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

List<DropdownMenuItem<String>> relationshipItems({String? extra}) => [
      if (extra != null &&
          extra.isNotEmpty &&
          !kRelationshipOptions.contains(extra))
        DropdownMenuItem(value: extra, child: Text(extra)),
      for (final r in kRelationshipOptions)
        DropdownMenuItem(value: r, child: Text(r)),
    ];
