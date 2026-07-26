import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/core/lifecycle/app_lifecycle.dart';

void main() {
  group('ResumeFromBackgroundDetector', () {
    test('a resumed with no background behind it does not fire', () {
      final detector = ResumeFromBackgroundDetector();

      expect(detector.onStateChange(AppLifecycleState.resumed), isFalse);
    });

    test('inactive alone never arms it', () {
      // The notification centre, the control centre, the app switcher and an
      // incoming call all report inactive. Refreshing on those would refetch
      // several times a minute for nothing.
      final detector = ResumeFromBackgroundDetector();

      expect(detector.onStateChange(AppLifecycleState.inactive), isFalse);
      expect(detector.isArmed, isFalse);
      expect(detector.onStateChange(AppLifecycleState.resumed), isFalse);
    });

    test('paused then resumed fires', () {
      final detector = ResumeFromBackgroundDetector();

      expect(detector.onStateChange(AppLifecycleState.paused), isFalse);
      expect(detector.isArmed, isTrue);
      expect(detector.onStateChange(AppLifecycleState.resumed), isTrue);
    });

    test('hidden arms it too', () {
      final detector = ResumeFromBackgroundDetector();

      expect(detector.onStateChange(AppLifecycleState.hidden), isFalse);
      expect(detector.onStateChange(AppLifecycleState.resumed), isTrue);
    });

    test('detached arms it too', () {
      final detector = ResumeFromBackgroundDetector();

      expect(detector.onStateChange(AppLifecycleState.detached), isFalse);
      expect(detector.onStateChange(AppLifecycleState.resumed), isTrue);
    });

    test('the full iOS round trip fires exactly once', () {
      final detector = ResumeFromBackgroundDetector();
      const leaving = [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ];
      const returning = [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
      ];

      for (final state in leaving) {
        expect(detector.onStateChange(state), isFalse, reason: '$state');
      }
      for (final state in returning) {
        expect(detector.onStateChange(state), isFalse, reason: '$state');
      }

      expect(detector.onStateChange(AppLifecycleState.resumed), isTrue);
    });

    test('a second resumed without another background does not fire', () {
      final detector = ResumeFromBackgroundDetector();

      detector.onStateChange(AppLifecycleState.paused);
      expect(detector.onStateChange(AppLifecycleState.resumed), isTrue);
      expect(detector.onStateChange(AppLifecycleState.resumed), isFalse);
    });

    test('two background trips fire twice', () {
      final detector = ResumeFromBackgroundDetector();

      for (var trip = 0; trip < 2; trip++) {
        detector.onStateChange(AppLifecycleState.paused);
        expect(detector.onStateChange(AppLifecycleState.resumed), isTrue);
      }
    });
  });

  group('AppLifecycleBus', () {
    test('broadcasts every emitted state', () async {
      final bus = AppLifecycleBus();
      addTearDown(bus.dispose);
      final seen = <AppLifecycleState>[];
      bus.stream.listen(seen.add);

      bus
        ..emit(AppLifecycleState.paused)
        ..emit(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);

      expect(seen, [AppLifecycleState.paused, AppLifecycleState.resumed]);
    });

    test('emitting after dispose is a no-op, not a throw', () {
      final bus = AppLifecycleBus()..dispose();

      expect(() => bus.emit(AppLifecycleState.resumed), returnsNormally);
    });
  });
}
