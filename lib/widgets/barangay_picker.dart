import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../constants/barangays.dart';

/// Field nga mo-open ug searchable list sa tanang barangay sa Cebu City.
class BarangayPickerField extends StatelessWidget {
  final String? value;
  final ValueChanged<String> onChanged;

  const BarangayPickerField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _BarangaySearchSheet(selected: value),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Barangay', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _open(context),
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: const InputDecoration(
              suffixIcon: Icon(Icons.arrow_drop_down_rounded),
            ),
            child: Text(
              value ?? 'Select barangay',
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

class _BarangaySearchSheet extends StatefulWidget {
  final String? selected;
  const _BarangaySearchSheet({required this.selected});

  @override
  State<_BarangaySearchSheet> createState() => _BarangaySearchSheetState();
}

class _BarangaySearchSheetState extends State<_BarangaySearchSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Lowercase, tangtang ang ñ/spaces/hyphens/periods para
  /// "tagbao" makakita ug "Tagba-o" ug "santo nino" makakita ug "Santo Niño".
  String _normalize(String s) => s
      .toLowerCase()
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'[^a-z0-9]'), '');

  List<String> get _filtered {
    final q = _normalize(_query);
    if (q.isEmpty) return kBarangays;
    return kBarangays.where((b) => _normalize(b).contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final height =
        (media.size.height - media.viewInsets.bottom - media.padding.top) * 0.9;
    final results = _filtered;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: height,
        child: Column(
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
                  'Select Barangay',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search barangay',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Text(
                        'No barangay found.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    )
                  : ListView.builder(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: results.length,
                      itemBuilder: (context, i) {
                        final name = results[i];
                        final isSelected = name == widget.selected;
                        return ListTile(
                          title: Text(
                            name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: AppColors.primary,
                                )
                              : null,
                          onTap: () => Navigator.pop(context, name),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}