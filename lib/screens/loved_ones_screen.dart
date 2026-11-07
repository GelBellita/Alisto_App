import 'dart:async';

import 'package:flutter/material.dart';

import '../models/loved_one_models.dart';
import '../services/loved_ones_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/loved_one_widgets.dart';
import 'add_loved_one_screen.dart';
import 'loved_one_details_screen.dart';

enum _Filter { all, online, offline, attention }

// =========================================================
// MY LOVED ONES — mobile version of templates/family/my_loved_ones.html.
// Search, 3 summary cards, filter tabs, one card per loved one, and
// "View Details". Replaces the old Contacts tab: emergency contacts now
// live inside each loved one's details, exactly like the web.
// =========================================================
class LovedOnesScreen extends StatefulWidget {
  const LovedOnesScreen({super.key});

  @override
  State<LovedOnesScreen> createState() => _LovedOnesScreenState();
}

class _LovedOnesScreenState extends State<LovedOnesScreen> {
  List<LovedOne>? _items;
  Object? _error;
  _Filter _filter = _Filter.all;
  String _search = '';
  StreamSubscription<List<LovedOne>>? _sub;

  @override
  void initState() {
    super.initState();
    // Re-loads whenever a loved one is added/removed (on web or app).
    _sub = LovedOnesService.lovedOnesStream().listen(
      (items) {
        if (mounted) {
          setState(() {
            _items = items;
            _error = null;
          });
        }
      },
      onError: (e) {
        if (mounted) setState(() => _error = e);
      },
    );
    // No timer here on purpose: a periodic reload re-reads every loved
    // one even while this tab is hidden (IndexedStack keeps it alive).
    // Pull down to refresh instead.
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool force = true}) async {
    try {
      final items = await LovedOnesService.loadLovedOnes(force: force);
      if (mounted) {
        setState(() {
          _items = items;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _openAdd() async {
    // No reload here: the family_elder_link listener already reloads
    // once when the new link appears.
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddLovedOneScreen()),
    );
  }

  Future<void> _openDetails(LovedOne e) async {
    var changed = false;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LovedOneDetailsScreen(
          elderId: e.id,
          initial: e,
          onChanged: () => changed = true,
        ),
      ),
    );
    // Only re-read when something on the card actually changed.
    if (changed) _refresh();
  }

  bool _matches(LovedOne e) {
    final okFilter = switch (_filter) {
      _Filter.all => true,
      _Filter.online => e.status == LovedOneStatus.online,
      _Filter.offline => e.status == LovedOneStatus.offline,
      _Filter.attention => e.status == LovedOneStatus.attention,
    };
    return okFilter &&
        (_search.isEmpty || e.name.toLowerCase().contains(_search));
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final online =
        items?.where((e) => e.status == LovedOneStatus.online).length ?? 0;
    final offline =
        items?.where((e) => e.status == LovedOneStatus.offline).length ?? 0;
    final attention =
        items?.where((e) => e.status == LovedOneStatus.attention).length ?? 0;
    final total = items?.length ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ResponsiveContent(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => _refresh(force: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              // ---- header ----
              Text(
                'My Loved Ones',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontSize: 22),
              ),
              const SizedBox(height: 2),
              Text(
                'View and monitor the people connected to your family account.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (v) =>
                          setState(() => _search = v.trim().toLowerCase()),
                      decoration: const InputDecoration(
                        hintText: 'Search by name...',
                        prefixIcon: Icon(Icons.search_rounded, size: 20),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _AddButton(onTap: _openAdd),
                ],
              ),
              const SizedBox(height: 14),

              // ---- summary cards ----
              Row(
                children: [
                  _SummaryCard(
                    icon: Icons.groups_rounded,
                    color: AppColors.primary,
                    label: 'Total Loved Ones',
                    value: total,
                    sub: 'Registered',
                    onTap: () => setState(() => _filter = _Filter.all),
                  ),
                  const SizedBox(width: 8),
                  _SummaryCard(
                    icon: Icons.wifi_rounded,
                    color: Accent.green,
                    label: 'Online Devices',
                    value: online,
                    sub: 'Active',
                    onTap: () => setState(() => _filter = _Filter.online),
                  ),
                  const SizedBox(width: 8),
                  _SummaryCard(
                    icon: Icons.warning_amber_rounded,
                    color: Accent.yellow,
                    label: 'Need Attention',
                    value: attention,
                    sub: 'Alert',
                    onTap: () => setState(() => _filter = _Filter.attention),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ---- filter tabs ----
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _chip('All ($total)', _Filter.all, null),
                    _chip('Online ($online)', _Filter.online, Accent.green),
                    _chip(
                      'Offline ($offline)',
                      _Filter.offline,
                      AppColors.textSecondary,
                    ),
                    _chip(
                      'Needs Attention ($attention)',
                      _Filter.attention,
                      Accent.yellow,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ---- cards ----
              if (_error != null && items == null)
                _Message(
                  icon: Icons.cloud_off_rounded,
                  text:
                      'Could not load your loved ones. Pull down to try again.',
                )
              else if (items == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (items.isEmpty)
                _EmptyState(onAdd: _openAdd)
              else ...[
                for (final e in items.where(_matches))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _LovedOneCard(
                      lovedOne: e,
                      onView: () => _openDetails(e),
                    ),
                  ),
                if (!items.any(_matches))
                  const _Message(
                    icon: Icons.search_off_rounded,
                    text: 'No loved ones match this filter.',
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, _Filter f, Color? dot) {
    final selected = _filter == f;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        onSelected: (_) => setState(() => _filter = f),
        selectedColor: AppColors.primary.withOpacity(0.14),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dot != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: 16, color: Colors.white),
              SizedBox(width: 4),
              Text(
                'Add Loved One',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final int value;
  final String sub;
  final VoidCallback onTap;
  const _SummaryCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AppCard(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 2,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textSecondary,
                  height: 1.2,
                ),
              ),
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                sub,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One loved-one card — same rows as the web's .loved-one-card.
class _LovedOneCard extends StatelessWidget {
  final LovedOne lovedOne;
  final VoidCallback onView;
  const _LovedOneCard({required this.lovedOne, required this.onView});

  @override
  Widget build(BuildContext context) {
    final e = lovedOne;
    return AppCard(
      padding: EdgeInsets.zero,
      borderColor: e.isEmergency
          ? AppColors.error.withOpacity(0.5)
          : AppColors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
            child: Row(
              children: [
                LovedOneAvatar(initials: e.initials, photoUrl: e.photoUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        e.relationship,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      LovedOneStatusPill(lovedOne: e),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                _DetailRow(
                  icon: Icons.schedule_rounded,
                  label: 'Last check-in',
                  value: e.lastCheckin,
                  overdue: e.checkinOverdue,
                ),
                _DetailRow(
                  icon: Icons.event_available_rounded,
                  label: 'Next medicine reminder',
                  value: e.nextMedicine,
                  overdue: e.medicineOverdue,
                ),
                _DetailRow(
                  icon: Icons.location_on_outlined,
                  label: 'Location',
                  value: e.location,
                ),
                if (e.deviceId != null) ...[
                  _DetailRow(
                    icon: Icons.smartphone_rounded,
                    label: 'Device number',
                    value: e.simNumber ?? 'Not reported',
                  ),
                  _DetailRow(
                    icon: Icons.account_balance_wallet_outlined,
                    label: e.loadText != null
                        ? 'Load · checked ${e.loadChecked}'
                        : 'Load',
                    value: e.loadText ?? 'Not checked yet',
                    overdue: e.loadLow,
                  ),
                ],
                _DetailRow(
                  icon: Icons.people_outline_rounded,
                  label: 'Connected accounts',
                  value: e.accountsText,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          InkWell(
            onTap: onView,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(14),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'View Details',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool overdue;
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.overdue = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: AppColors.primary),
          ),
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
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: overdue ? AppColors.error : AppColors.textPrimary,
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

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const Icon(
            Icons.groups_rounded,
            size: 48,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 10),
          const Text(
            'No loved ones linked to your account yet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          _AddButton(onTap: onAdd),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Message({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.textSecondary),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
