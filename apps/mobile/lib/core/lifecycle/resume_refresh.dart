import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/lifecycle/app_lifecycle.dart';

/// How long data of a given kind stays fresh enough to survive a return to
/// the foreground without being refetched.
///
/// Coming back to the app is a frequent event, so this is a battery decision
/// as much as a freshness one: the more a refresh costs, the wider the window.
abstract final class ResumeRefresh {
  /// Plain HTTP list endpoints (clubs, join requests). Cheap, and the thing
  /// the user came back to check.
  static const lists = Duration(seconds: 30);

  /// Remote forecast. The upstream model publishes hourly, so two minutes is
  /// already fresher than the data itself.
  static const forecast = Duration(minutes: 2);

  /// A GPS fix: the most expensive refresh in the app.
  static const location = Duration(minutes: 5);
}

/// The clock [ResumeRefreshRef.refreshOnAppResume] measures freshness with.
///
/// Overridden in tests so the intervals above can be exercised without
/// waiting minutes of wall-clock time.
final resumeRefreshClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Decides whether a lifecycle transition should trigger a refetch.
///
/// Split out from [ResumeRefreshRef.refreshOnAppResume] so the two rules that
/// keep it cheap — a real background trip, and a minimum gap since the last
/// fetch — can be tested without a widget tree.
class ResumeRefreshPolicy {
  ResumeRefreshPolicy({
    required Duration minInterval,
    DateTime Function()? clock,
  }) : this._(minInterval, clock ?? DateTime.now);

  ResumeRefreshPolicy._(this.minInterval, DateTime Function() clock)
      : _clock = clock,
        _lastFetch = clock();

  /// Minimum time since the last fetch before a foreground return refetches.
  final Duration minInterval;

  final DateTime Function() _clock;
  final ResumeFromBackgroundDetector _detector = ResumeFromBackgroundDetector();

  DateTime _lastFetch;

  /// True when [state] ends a real trip to the background *and* the data is
  /// old enough to be worth refetching. Records the refresh when it says yes.
  bool shouldRefresh(AppLifecycleState state) {
    if (!_detector.onStateChange(state)) return false;
    final now = _clock();
    if (now.difference(_lastFetch) < minInterval) return false;
    _lastFetch = now;
    return true;
  }
}

/// Foreground-refresh support for providers.
extension ResumeRefreshRef on Ref<Object?> {
  /// Refetches this provider when the user comes back to the app.
  ///
  /// Call it at the top of the provider body:
  ///
  /// ```dart
  /// final myGroupsProvider = FutureProvider<List<Group>>((ref) async {
  ///   ref.refreshOnAppResume(minInterval: ResumeRefresh.lists);
  ///   final response = await ref.read(groupRepositoryProvider).getGroups();
  ///   return response.items;
  /// });
  /// ```
  ///
  /// The subscription lives for exactly one run of the body, so [minInterval]
  /// is measured from the last real fetch: a pull-to-refresh or an error retry
  /// resets the window for free, and there is nothing to keep in sync.
  ///
  /// Cheap by construction:
  /// - only a real trip to the background counts, never an `inactive` blip
  ///   (see [ResumeFromBackgroundDetector]);
  /// - nothing refetches within [minInterval] of the last fetch;
  /// - Riverpod only re-runs an invalidated provider that still has listeners,
  ///   so data behind a screen the user is not looking at is merely marked
  ///   stale and refetches when that screen comes back.
  void refreshOnAppResume({required Duration minInterval}) {
    final policy = ResumeRefreshPolicy(
      minInterval: minInterval,
      clock: read(resumeRefreshClockProvider),
    );
    final subscription = read(appLifecycleBusProvider).stream.listen((state) {
      if (policy.shouldRefresh(state)) invalidateSelf();
    });
    onDispose(subscription.cancel);
  }
}
