import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What a [GpsStreamWatchdog] reads as "now".
///
/// A test seam, mirroring `resumeRefreshClockProvider`: aging a GPS stream by
/// ninety seconds must not mean waiting ninety seconds.
final gpsWatchdogClockProvider = Provider<DateTime Function()>((ref) {
  return DateTime.now;
});

/// Notices when a long-running GPS stream has gone quiet, so its owner can
/// re-subscribe.
///
/// Trip recording and the anchor watch both hold a `getPositionStream`
/// subscription for hours while Navis is minimized. Two things break that in
/// the field and **neither of them closes the stream**, so checking the
/// subscription for null never catches either:
///
///  * iOS stops delivering when it decides the app has had enough background
///    time (and `pauseLocationUpdatesAutomatically`, if it ever ends up on,
///    pauses without ever resuming);
///  * Android drops the foreground service on a memory trim.
///
/// So aliveness is judged by evidence instead: every fix is stamped, and on
/// each lifecycle transition the owner asks whether anything has arrived
/// recently. A restart is cheap and idempotent — the same call `resume()`
/// already makes — so [timeout] is set well past the longest legitimate
/// silence (a moored boat inside its distance filter produces no fixes at all)
/// and a false restart costs nothing but a re-subscribe.
class GpsStreamWatchdog {
  GpsStreamWatchdog({
    required this.timeout,
    required this.onRestart,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// How long a stream may stay silent before it is presumed dead.
  final Duration timeout;

  /// Re-subscribes the stream. Must be safe to call repeatedly.
  final void Function() onRestart;

  final DateTime Function() _clock;

  DateTime? _lastFix;
  bool _active = false;

  /// Whether the watchdog is currently guarding a stream.
  bool get isActive => _active;

  /// Begins guarding. The clock starts now, so a stream that never delivers
  /// its first fix is still noticed after [timeout].
  void start() {
    _active = true;
    _lastFix = _clock();
  }

  /// Stamps a delivered fix. Evidence the stream is alive.
  void recordFix() => _lastFix = _clock();

  /// Stops guarding (recording stopped, watch disarmed, notifier disposed).
  void stop() {
    _active = false;
    _lastFix = null;
  }

  /// Restarts the stream when it looks dead. [hasSubscription] is the owner's
  /// null check — false is an unambiguous restart. Returns whether it fired.
  bool check({required bool hasSubscription}) {
    if (!_active) return false;
    if (!hasSubscription) {
      _restart();
      return true;
    }
    final last = _lastFix;
    if (last != null && _clock().difference(last) < timeout) return false;
    _restart();
    return true;
  }

  void _restart() {
    // Give the new subscription a full grace period before it is judged again.
    _lastFix = _clock();
    onRestart();
  }
}
