import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/core/lifecycle/gps_stream_watchdog.dart';

void main() {
  var now = DateTime(2026, 8, 18, 10);
  var restarts = 0;

  GpsStreamWatchdog build({Duration timeout = const Duration(seconds: 90)}) {
    return GpsStreamWatchdog(
      timeout: timeout,
      onRestart: () => restarts++,
      clock: () => now,
    );
  }

  setUp(() {
    now = DateTime(2026, 8, 18, 10);
    restarts = 0;
  });

  test('does nothing while it is not guarding anything', () {
    final watchdog = build();

    expect(watchdog.check(hasSubscription: false), isFalse);
    expect(restarts, 0);
  });

  test('restarts a stream that is simply gone', () {
    final watchdog = build()..start();

    expect(watchdog.check(hasSubscription: false), isTrue);
    expect(restarts, 1);
  });

  test('leaves a stream that is still delivering alone', () {
    final watchdog = build()..start();
    now = now.add(const Duration(seconds: 80));
    watchdog.recordFix();
    now = now.add(const Duration(seconds: 30));

    expect(watchdog.check(hasSubscription: true), isFalse);
    expect(restarts, 0);
  });

  test('restarts a subscription that stopped delivering', () {
    // The failure this exists for: iOS suspends delivery and Android drops the
    // service without closing the stream, so the subscription looks healthy.
    final watchdog = build()..start();
    watchdog.recordFix();
    now = now.add(const Duration(seconds: 91));

    expect(watchdog.check(hasSubscription: true), isTrue);
    expect(restarts, 1);
  });

  test('notices a stream that never delivered a first fix', () {
    final watchdog = build()..start();
    now = now.add(const Duration(seconds: 91));

    expect(watchdog.check(hasSubscription: true), isTrue);
    expect(restarts, 1);
  });

  test('gives a fresh stream a full grace period before judging it again', () {
    final watchdog = build()..start();
    now = now.add(const Duration(seconds: 91));
    watchdog.check(hasSubscription: true);

    // Immediately after a restart, nothing has had time to arrive.
    expect(watchdog.check(hasSubscription: true), isFalse);
    expect(restarts, 1);

    now = now.add(const Duration(seconds: 91));
    expect(watchdog.check(hasSubscription: true), isTrue);
    expect(restarts, 2);
  });

  test('stops guarding once the owner is done', () {
    final watchdog = build()..start();
    watchdog.stop();
    now = now.add(const Duration(hours: 1));

    expect(watchdog.isActive, isFalse);
    expect(watchdog.check(hasSubscription: false), isFalse);
    expect(restarts, 0);
  });
}
