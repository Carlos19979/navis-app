import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/lifecycle/app_lifecycle.dart';
import 'package:navis_mobile/core/lifecycle/resume_refresh.dart';

/// Drives app lifecycle transitions and the resume-refresh clock, so tests of
/// foreground refreshing are deterministic and take no wall-clock time.
///
/// Add [overrides] to the container or `ProviderScope` under test, then call
/// [leaveAndReturn] (a real trip to the background) or [blip] (an `inactive`
/// that is not).
class FakeLifecycle {
  FakeLifecycle({DateTime? start}) : now = start ?? DateTime(2026, 7, 26, 10);

  final AppLifecycleBus bus = AppLifecycleBus();

  /// What the resume-refresh policy reads as "now". Advanced by
  /// [leaveAndReturn].
  DateTime now;

  List<Override> get overrides => [
        appLifecycleBusProvider.overrideWithValue(bus),
        resumeRefreshClockProvider.overrideWithValue(() => now),
      ];

  /// Backgrounds the app, spends [away] there, and comes back. The default is
  /// long enough to be past every interval in [ResumeRefresh].
  void leaveAndReturn({Duration away = const Duration(hours: 1)}) {
    bus.emit(AppLifecycleState.paused);
    now = now.add(away);
    bus.emit(AppLifecycleState.resumed);
  }

  /// A notification-centre pull, a control-centre swipe or the app switcher:
  /// `inactive` then `resumed`, with no trip to the background.
  void blip() {
    bus
      ..emit(AppLifecycleState.inactive)
      ..emit(AppLifecycleState.resumed);
  }

  /// Lets the lifecycle stream and Riverpod's scheduler settle.
  Future<void> settle(ProviderContainer container) async {
    await Future<void>.delayed(Duration.zero);
    await container.pump();
  }

  void dispose() => bus.dispose();
}
