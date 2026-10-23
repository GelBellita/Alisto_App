import 'dart:async';

/// One Firestore listener shared by every widget that asks for the same
/// stream, replaying the latest value to each new listener.
///
/// Why this exists: StreamBuilder cancels and re-listens whenever it is
/// handed a different Stream instance, and every call to something like
/// `FirestoreService.alertsStream()` used to build a brand-new query. A
/// StreamBuilder nested inside another builder (Home's device card is
/// rebuilt on every 30-second Pi heartbeat) therefore restarted its
/// Firestore listener over and over -- and each restart is billed as a
/// fresh read of every matching document. Sharing one listener means
/// Firestore only charges for the first snapshot and for documents that
/// actually change afterwards.
///
/// The source subscription is kept alive for [_idleGrace] after the last
/// listener leaves, so a StreamBuilder swapping streams (cancel, then
/// listen again) or a quick back-and-forth between screens doesn't tear
/// the Firestore listener down and pay for the full snapshot again.
class SharedStream<T> {
  SharedStream(this._source, {this.onDone});

  static const Duration _idleGrace = Duration(minutes: 2);

  final Stream<T> Function() _source;

  /// Called once the source finishes (or errors and closes), so the owner
  /// can drop this instance and build a fresh one on the next request.
  final void Function()? onDone;

  final Set<MultiStreamController<T>> _listeners = {};
  StreamSubscription<T>? _sub;
  Timer? _idleTimer;
  bool _hasValue = false;
  late T _latest;
  bool _closed = false;

  late final Stream<T> stream = Stream<T>.multi((controller) {
    _idleTimer?.cancel();
    _idleTimer = null;
    if (_closed) {
      controller.close();
      return;
    }
    _listeners.add(controller);
    if (_hasValue) controller.add(_latest);
    _sub ??= _source().listen(
      (value) {
        _hasValue = true;
        _latest = value;
        for (final l in _listeners.toList()) {
          l.add(value);
        }
      },
      onError: (Object error, StackTrace stack) {
        for (final l in _listeners.toList()) {
          l.addError(error, stack);
        }
      },
      onDone: _finish,
    );
    controller.onCancel = () {
      _listeners.remove(controller);
      if (_listeners.isEmpty && !_closed) {
        _idleTimer?.cancel();
        _idleTimer = Timer(_idleGrace, dispose);
      }
    };
  });

  void _finish() {
    if (_closed) return;
    _closed = true;
    _idleTimer?.cancel();
    _sub = null;
    for (final l in _listeners.toList()) {
      l.close();
    }
    _listeners.clear();
    onDone?.call();
  }

  /// Stops the Firestore listener. Safe to call more than once.
  void dispose() {
    _sub?.cancel();
    _finish();
  }
}
