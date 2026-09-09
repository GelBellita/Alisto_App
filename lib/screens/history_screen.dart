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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ResponsiveContent(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  'History',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontSize: 22),
                ),
              ),
              const SizedBox(height: 14),
              _SegmentedTabs(
                labels: _tabs,
                index: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
              const SizedBox(height: 16),
              StreamBuilder<dynamic>(
                stream: FirestoreService.alertsStream(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  var docs = snapshot.data.docs;
                  var alerts = docs
                      .map<AlertModel>((d) => AlertModel.fromDoc(d))
                      .toList();

                  if (_tab == 1) {
                    alerts = alerts
                        .where((a) => a.type == 'emergency')
                        .toList();
                  } else if (_tab == 2) {
                    alerts = alerts
                        .where((a) => a.type != 'emergency')
                        .toList();
                  }

                  if (alerts.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'No history yet. Events from your Alisto device\nwill show up here.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      for (int i = 0; i < alerts.length; i++) ...[
                        if (i > 0) const SizedBox(height: 10),
                        _HistoryEntryCard(alert: alerts[i]),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
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

class _HistoryEntryCard extends StatelessWidget {
  final AlertModel alert;
  const _HistoryEntryCard({required this.alert});

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
    return AppCard(
      color: _highlighted
          ? AppColors.error.withOpacity(0.05)
          : AppColors.surface,
      borderColor: _highlighted
          ? AppColors.error.withOpacity(0.35)
          : AppColors.border,
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
