import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/firestore_service.dart';
import '../models/app_models.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _tab = 0;
  static const _tabs = ['All', 'Emergency', 'System'];

  // Created ONCE, not in build() -- every checkbox tap rebuilds this
  // screen, and a fresh stream on every rebuild would re-subscribe to
  // Firestore and flash the loading spinner each time.
  late final Stream<List<AlertModel>> _alertsStream =
      FirestoreService.alertsStream();

  // ---- Selection mode (long-press or ⋮ > Select) ----
  bool _selectMode = false;
  final Set<String> _selected = {};
  bool _deleting = false;

  List<AlertModel> _filter(List<AlertModel> alerts) {
    switch (_tab) {
      case 1:
        return alerts.where((a) => a.type == 'emergency').toList();
      case 2:
        return alerts.where((a) => a.type != 'emergency').toList();
      default:
        return alerts;
    }
  }

  void _enterSelectMode([String? firstId]) => setState(() {
    _selectMode = true;
    if (firstId != null) _selected.add(firstId);
  });

  void _exitSelectMode() => setState(() {
    _selectMode = false;
    _selected.clear();
  });

  void _toggle(String id) => setState(() {
    if (!_selected.remove(id)) _selected.add(id);
  });

  void _toggleAll(List<AlertModel> visible) => setState(() {
    final ids = visible.map((a) => a.id);
    final allSelected = ids.every(_selected.contains);
    allSelected ? _selected.removeAll(ids) : _selected.addAll(ids);
  });

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.error : null,
      ),
    );
  }

  Future<bool?> _confirmDelete(int count, {required bool all}) {
    final plural = count == 1 ? '' : 's';
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          all
              ? 'Delete all notifications?'
              : 'Delete $count notification$plural?',
        ),
        content: Text(
          '${all ? 'All $count notification$plural' : (count == 1 ? 'This notification' : 'These notifications')} '
          'will be removed from your history. Other family members '
          'linked to this device will still see ${count == 1 ? 'it' : 'them'}.',
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
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Soft-deletes the given alerts for THIS user only (adds their uid to
  /// each doc's `hidden_for` — see FirestoreService.hideAlerts). The live
  /// stream filters them out, so the cards disappear without any manual
  /// refresh.
  Future<void> _delete(List<String> ids, {required bool all}) async {
    if (ids.isEmpty || _deleting) return;
    final confirmed = await _confirmDelete(ids.length, all: all);
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await FirestoreService.hideAlerts(ids);
      if (!mounted) return;
      _exitSelectMode();
      _showMessage(
        '${ids.length} notification${ids.length == 1 ? '' : 's'} deleted.',
      );
    } catch (e) {
      if (mounted) _showMessage('Could not delete: $e', error: true);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AlertModel>>(
      stream: _alertsStream,
      builder: (context, snapshot) {
        final visible = _filter(snapshot.data ?? const <AlertModel>[]);
        // Only count selections that are still on screen (an alert
        // deleted elsewhere, or hidden by the tab filter, can't be
        // "selected").
        final selectedIds = [
          for (final a in visible)
            if (_selected.contains(a.id)) a.id,
        ];
        final allSelected =
            visible.isNotEmpty && selectedIds.length == visible.length;

        return Scaffold(
          backgroundColor: AppColors.background,
          bottomNavigationBar: _selectMode
              ? _DeleteBar(
                  count: selectedIds.length,
                  deleting: _deleting,
                  onDelete: () => _delete(selectedIds, all: false),
                )
              : null,
          body: ResponsiveContent(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () =>
                  Future.delayed(const Duration(milliseconds: 600)),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _selectMode
                        ? _SelectionHeader(
                            count: selectedIds.length,
                            onClose: _exitSelectMode,
                          )
                        : _NormalHeader(
                            hasItems: visible.isNotEmpty,
                            onSelect: () => _enterSelectMode(),
                            onDeleteAll: () => _delete(
                              visible.map((a) => a.id).toList(),
                              all: true,
                            ),
                          ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        // Scrolls sideways on very narrow phones instead
                        // of overflowing when "Select all" is showing.
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: _SegmentedTabs(
                              labels: _tabs,
                              index: _tab,
                              onChanged: (i) => setState(() {
                                _tab = i;
                                _selected.clear();
                              }),
                            ),
                          ),
                        ),
                        if (_selectMode)
                          _SelectAllButton(
                            allSelected: allSelected,
                            onTap: visible.isEmpty
                                ? null
                                : () => _toggleAll(visible),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildList(snapshot, visible),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildList(
    AsyncSnapshot<List<AlertModel>> snapshot,
    List<AlertModel> visible,
  ) {
    // Check hasError BEFORE hasData -- a stream that fails (e.g. no
    // device linked yet) never sets hasData, so checking hasData first
    // would spin forever.
    if (snapshot.hasError) {
      return _CenteredMessage(
        'No device is linked to this account yet.\n'
        'Please finish device registration or linking first.',
      );
    }
    if (!snapshot.hasData) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (visible.isEmpty) {
      return _CenteredMessage(
        'No history yet. Events from your Alisto device\nwill show up here.',
      );
    }

    return Column(
      children: [
        for (int i = 0; i < visible.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _HistoryEntryCard(
            alert: visible[i],
            selectMode: _selectMode,
            selected: _selected.contains(visible[i].id),
            onTap: _selectMode ? () => _toggle(visible[i].id) : null,
            onLongPress: _selectMode
                ? null
                : () => _enterSelectMode(visible[i].id),
          ),
        ],
      ],
    );
  }
}

// =========================================================
// HEADERS
// =========================================================
/// Default header: title, plus a ⋮ menu with "Select" and "Delete all".
/// Shows a back arrow only when this screen was pushed (e.g. from the
/// Home bell icon), not when it's a bottom-nav tab.
class _NormalHeader extends StatelessWidget {
  final bool hasItems;
  final VoidCallback onSelect;
  final VoidCallback onDeleteAll;
  const _NormalHeader({
    required this.hasItems,
    required this.onSelect,
    required this.onDeleteAll,
  });

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    return SizedBox(
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            'History',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontSize: 22),
          ),
          if (canPop)
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.textPrimary,
                ),
                onPressed: () => Navigator.maybePop(context),
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: PopupMenuButton<String>(
              enabled: hasItems,
              icon: Icon(
                Icons.more_vert_rounded,
                color: hasItems
                    ? AppColors.textPrimary
                    : AppColors.textSecondary.withOpacity(0.4),
              ),
              color: AppColors.background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              onSelected: (value) =>
                  value == 'select' ? onSelect() : onDeleteAll(),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'select',
                  child: Row(
                    children: [
                      Icon(Icons.checklist_rounded, size: 19),
                      SizedBox(width: 10),
                      Text('Select'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete_all',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_sweep_rounded,
                        size: 19,
                        color: AppColors.error,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Delete all',
                        style: TextStyle(color: AppColors.error),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Header while selecting: ✕ to cancel and "N selected".
class _SelectionHeader extends StatelessWidget {
  final int count;
  final VoidCallback onClose;
  const _SelectionHeader({required this.count, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Cancel',
            icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
            onPressed: onClose,
          ),
          const SizedBox(width: 4),
          Text(
            count == 0 ? 'Select items' : '$count selected',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontSize: 18),
          ),
        ],
      ),
    );
  }
}

/// "Select all ◯" — sits at the right end of the filter-tabs row, lined
/// up with the check circles on the cards below it.
class _SelectAllButton extends StatelessWidget {
  final bool allSelected;
  final VoidCallback? onTap;
  const _SelectAllButton({required this.allSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 13, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select all',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            _SelectCircle(selected: allSelected, size: 24),
          ],
        ),
      ),
    );
  }
}

/// Sticky red action bar shown at the bottom while selecting.
class _DeleteBar extends StatelessWidget {
  final int count;
  final bool deleting;
  final VoidCallback onDelete;
  const _DeleteBar({
    required this.count,
    required this.deleting,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: ElevatedButton.icon(
          onPressed: count == 0 || deleting ? null : onDelete,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
          ),
          icon: deleting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.delete_outline_rounded),
          label: Text(
            count == 0 ? 'Select notifications to delete' : 'Delete ($count)',
          ),
        ),
      ),
    );
  }
}

/// Round check indicator (Gmail / Android-notification style).
class _SelectCircle extends StatelessWidget {
  final bool selected;
  final double size;
  const _SelectCircle({required this.selected, this.size = 34});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: size,
      height: size,
      margin: const EdgeInsets.only(left: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.primary : Colors.transparent,
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.border,
          width: 2,
        ),
      ),
      child: selected
          ? Icon(Icons.check_rounded, size: size * 0.6, color: Colors.white)
          : null,
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  final String text;
  const _CenteredMessage(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  const _SegmentedTabs({
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(labels.length, (i) {
        final selected = i == index;
        return Padding(
          padding: EdgeInsets.only(right: i == labels.length - 1 ? 0 : 8),
          child: GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Text(
                labels[i],
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// =========================================================
// ENTRY CARD
// =========================================================
class _HistoryEntryCard extends StatefulWidget {
  final AlertModel alert;
  final bool selectMode;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  const _HistoryEntryCard({
    required this.alert,
    required this.selectMode,
    required this.selected,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<_HistoryEntryCard> createState() => _HistoryEntryCardState();
}

class _HistoryEntryCardState extends State<_HistoryEntryCard> {
  bool _responding = false;

  AlertModel get alert => widget.alert;

  Future<void> _respond() async {
    setState(() => _responding = true);
    try {
      await FirestoreService.acknowledgeAlert(alert.id);
      // No need to setState back to false on success -- the alertsStream
      // will emit the updated (acknowledged=true) doc and rebuild this
      // card without the button.
    } catch (e) {
      if (!mounted) return;
      setState(() => _responding = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not mark as responded: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  IconData get _icon {
    switch (alert.type) {
      case 'emergency':
        return Icons.notifications_active_rounded;
      case 'medicine':
        return Icons.medication_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  Color get _iconColor {
    switch (alert.type) {
      case 'emergency':
        return AppColors.error;
      case 'medicine':
        return AppColors.primary;
      default:
        return Accent.green;
    }
  }

  bool get _highlighted => alert.type == 'emergency';

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;

    final Color cardColor;
    final Color borderColor;
    if (selected) {
      cardColor = AppColors.primary.withOpacity(0.07);
      borderColor = AppColors.primary;
    } else if (_highlighted) {
      cardColor = AppColors.error.withOpacity(0.05);
      borderColor = AppColors.error.withOpacity(0.35);
    } else {
      cardColor = AppColors.surface;
      borderColor = AppColors.border;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AppCard(
          color: cardColor,
          borderColor: borderColor,
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _iconColor.withOpacity(0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(_icon, size: 17, color: _iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            alert.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: _highlighted
                                  ? AppColors.error
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          alert.time,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _highlighted
                                ? AppColors.error
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    for (final line in alert.lines)
                      Text(
                        line,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    // Respond button is hidden while selecting so a tap
                    // can only ever mean "toggle this card".
                    if (_highlighted && !widget.selectMode) ...[
                      const SizedBox(height: 8),
                      if (alert.acknowledged)
                        const Row(
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 14,
                              color: Accent.green,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Responded',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Accent.green,
                              ),
                            ),
                          ],
                        )
                      else
                        SizedBox(
                          height: 30,
                          child: OutlinedButton(
                            onPressed: _responding ? null : _respond,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                              minimumSize: const Size(0, 30),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            ),
                            child: _responding
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Respond',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              if (widget.selectMode)
                _SelectCircle(selected: selected, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
