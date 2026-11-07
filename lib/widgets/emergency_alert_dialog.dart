import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart' show rootNavigatorKey;
import '../models/app_models.dart';
import '../services/alarm_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

/// Which emergencies the full-screen card was already shown for during this
/// app session -- a push and the live alert list both report the same
/// emergency, and the card must open only once for it.
class EmergencyCardTracker {
  static final Set<String> shown = <String>{};
}

/// Opens [EmergencyAlertDialog] for any recent emergency that nobody has
/// acknowledged yet, whenever the app is open -- including when it is opened
/// AFTER the phone already started ringing. The push handler (main.dart)
/// only shows the card if the app was in the foreground at the exact moment
/// the push arrived; with the app in the background or the phone locked,
/// only the native alarm rang and nothing was shown once the app opened.
/// Wrap the signed-in screen with this.
class EmergencyAlertWatcher extends StatefulWidget {
  final Widget child;
  const EmergencyAlertWatcher({super.key, required this.child});

  @override
  State<EmergencyAlertWatcher> createState() => _EmergencyAlertWatcherState();
}

class _EmergencyAlertWatcherState extends State<EmergencyAlertWatcher> {
  StreamSubscription<List<AlertModel>>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = FirestoreService.alertsStream().listen(
      _onAlerts,
      onError: (_) {}, // best-effort: the push still works without this
    );
  }

  void _onAlerts(List<AlertModel> alerts) {
    final now = DateTime.now();
    for (final alert in alerts) {
      if (!alert.needsEmergencyCard(now, EmergencyCardTracker.shown)) continue;
      EmergencyCardTracker.shown.add(alert.id);
      final overlay = rootNavigatorKey.currentState?.overlay?.context;
      if (overlay == null) continue;
      showDialog<void>(
        context: overlay,
        barrierDismissible: false,
        builder: (_) => EmergencyAlertDialog(
          title: alert.title.isEmpty ? 'ALISTO Emergency Alert' : alert.title,
          body: '${alert.title.isEmpty ? 'Emergency' : alert.title}. '
              'Please check immediately.',
          alertId: alert.id,
        ),
      );
      break; // one card at a time; acknowledging also acknowledges the rest
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Full-attention floating card shown while the app is open and a push
/// notification for a real emergency arrives (see main.dart's
/// NotificationService.onForegroundMessage). Deliberately NOT dismissible
/// by tapping outside or the back button (PopScope canPop: false) -- the
/// only way out is pressing OK, which is also the only way this device
/// records that a family member actually saw it (see acknowledgeAlert()).
class EmergencyAlertDialog extends StatefulWidget {
  final String title;
  final String body;
  final String? alertId;

  const EmergencyAlertDialog({
    super.key,
    required this.title,
    required this.body,
    this.alertId,
  });

  @override
  State<EmergencyAlertDialog> createState() => _EmergencyAlertDialogState();
}

class _EmergencyAlertDialogState extends State<EmergencyAlertDialog> {
  bool _acknowledging = false;

  Future<void> _onOk() async {
    setState(() => _acknowledging = true);
    AlarmService.stop();

    if (widget.alertId != null) {
      try {
        await FirestoreService.acknowledgeAlert(widget.alertId!);
      } catch (_) {
        // Best-effort -- the dialog still closes. The alert doc stays
        // "acknowledged: false" until a later successful call (e.g. the
        // History screen's own Respond button), so nothing is lost.
      }
    }

    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(color: Colors.black38, blurRadius: 32, offset: Offset(0, 12)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_rounded, color: AppColors.error, size: 38),
              ),
              const SizedBox(height: 18),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 10),
              Text(
                widget.body,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14.5, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _acknowledging ? null : _onOk,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _acknowledging
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : const Text(
                          'OK, I saw this',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
