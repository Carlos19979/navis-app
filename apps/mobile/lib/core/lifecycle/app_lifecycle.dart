import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App lifecycle transitions, published once for the whole app.
///
/// Providers that need to refetch when the user comes back to Navis listen
/// here, instead of every screen wiring its own [WidgetsBindingObserver] and
/// hand-invalidating whatever it happens to know about.
class AppLifecycleBus {
  AppLifecycleBus();

  final StreamController<AppLifecycleState> _controller =
      StreamController<AppLifecycleState>.broadcast();

  Stream<AppLifecycleState> get stream => _controller.stream;

  /// Publishes [state]. Fed by the Flutter binding in the app, and called
  /// directly by tests that simulate a trip to the background.
  void emit(AppLifecycleState state) {
    if (_controller.isClosed) return;
    _controller.add(state);
  }

  void dispose() {
    _controller.close();
  }
}

/// The one bus, fed by the real Flutter binding.
///
/// Override this in tests to drive lifecycle transitions by hand.
final appLifecycleBusProvider = Provider<AppLifecycleBus>((ref) {
  final bus = AppLifecycleBus();
  final bridge = _attachBridge(bus);
  ref.onDispose(() {
    if (bridge != null) {
      WidgetsBinding.instance.removeObserver(bridge);
    }
    bus.dispose();
  });
  return bus;
});

/// Bridges the Flutter binding into [bus], or returns null when there is no
/// binding to observe (a plain unit test). A silent bus is a missing refresh;
/// a thrown error here would take every provider that depends on it down.
_LifecycleBridge? _attachBridge(AppLifecycleBus bus) {
  try {
    final bridge = _LifecycleBridge(bus);
    WidgetsBinding.instance.addObserver(bridge);
    return bridge;
  } catch (e) {
    debugPrint('lifecycle: no binding to observe: $e');
    return null;
  }
}

class _LifecycleBridge with WidgetsBindingObserver {
  _LifecycleBridge(this._bus);

  final AppLifecycleBus _bus;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _bus.emit(state);
}

/// Answers "did the app just come back from the background?".
///
/// [AppLifecycleState.inactive] on its own is not a trip to the background:
/// iOS reports it for a pulled-down notification centre, a control-centre
/// swipe, an incoming call or the app switcher. Treating those as a return to
/// the foreground would refetch several times a minute, so only a real
/// `paused` / `hidden` / `detached` arms the next `resumed`.
class ResumeFromBackgroundDetector {
  bool _armed = false;

  /// Whether a trip to the background has been seen and not yet consumed.
  bool get isArmed => _armed;

  /// Feeds one transition. Returns true exactly once per trip to the
  /// background, on the `resumed` that ends it.
  bool onStateChange(AppLifecycleState state) => switch (state) {
        AppLifecycleState.paused ||
        AppLifecycleState.hidden ||
        AppLifecycleState.detached =>
          _arm(),
        AppLifecycleState.resumed => _consume(),
        AppLifecycleState.inactive => false,
      };

  bool _arm() {
    _armed = true;
    return false;
  }

  bool _consume() {
    final wasArmed = _armed;
    _armed = false;
    return wasArmed;
  }
}
