import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/core/lifecycle/app_lifecycle.dart';
import 'package:navis_mobile/core/lifecycle/resume_refresh.dart';

void main() {
  group('ResumeRefreshPolicy', () {
    test('refuses a refresh inside the minimum interval', () {
      var now = DateTime(2026, 7, 26, 10);
      final policy = ResumeRefreshPolicy(
        minInterval: const Duration(seconds: 30),
        clock: () => now,
      );

      policy.shouldRefresh(AppLifecycleState.paused);
      now = now.add(const Duration(seconds: 5));

      expect(policy.shouldRefresh(AppLifecycleState.resumed), isFalse);
    });

    test('allows a refresh once the interval has passed', () {
      var now = DateTime(2026, 7, 26, 10);
      final policy = ResumeRefreshPolicy(
        minInterval: const Duration(seconds: 30),
        clock: () => now,
      );

      policy.shouldRefresh(AppLifecycleState.paused);
      now = now.add(const Duration(seconds: 30));

      expect(policy.shouldRefresh(AppLifecycleState.resumed), isTrue);
    });

    test('a granted refresh restarts the window', () {
      var now = DateTime(2026, 7, 26, 10);
      final policy = ResumeRefreshPolicy(
        minInterval: const Duration(seconds: 30),
        clock: () => now,
      );

      now = now.add(const Duration(minutes: 1));
      policy.shouldRefresh(AppLifecycleState.paused);
      expect(policy.shouldRefresh(AppLifecycleState.resumed), isTrue);

      // Straight back out and in again: the data is one second old.
      now = now.add(const Duration(seconds: 1));
      policy.shouldRefresh(AppLifecycleState.paused);
      expect(policy.shouldRefresh(AppLifecycleState.resumed), isFalse);
    });

    test('never refreshes without a trip to the background', () {
      var now = DateTime(2026, 7, 26, 10);
      final policy = ResumeRefreshPolicy(
        minInterval: const Duration(seconds: 30),
        clock: () => now,
      );

      now = now.add(const Duration(hours: 3));

      expect(policy.shouldRefresh(AppLifecycleState.inactive), isFalse);
      expect(policy.shouldRefresh(AppLifecycleState.resumed), isFalse);
    });
  });

  group('Ref.refreshOnAppResume', () {
    late AppLifecycleBus bus;

    setUp(() {
      bus = AppLifecycleBus();
      addTearDown(bus.dispose);
    });

    /// A provider that counts its fetches and refreshes on foreground return.
    ({FutureProvider<int> provider, int Function() calls}) countingProvider({
      Duration minInterval = Duration.zero,
    }) {
      var calls = 0;
      final provider = FutureProvider<int>((ref) async {
        ref.refreshOnAppResume(minInterval: minInterval);
        return ++calls;
      });
      return (provider: provider, calls: () => calls);
    }

    ProviderContainer makeContainer() {
      final container = ProviderContainer(
        overrides: [appLifecycleBusProvider.overrideWithValue(bus)],
      );
      addTearDown(container.dispose);
      return container;
    }

    Future<void> backgroundTrip(ProviderContainer container) async {
      bus
        ..emit(AppLifecycleState.paused)
        ..emit(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      await container.pump();
    }

    test('refetches a watched provider when the app comes back', () async {
      final counting = countingProvider();
      final container = makeContainer();
      container.listen(counting.provider, (_, __) {});
      await container.read(counting.provider.future);
      expect(counting.calls(), 1);

      await backgroundTrip(container);

      expect(await container.read(counting.provider.future), 2);
    });

    test('does not refetch inside the minimum interval', () async {
      final counting = countingProvider(minInterval: const Duration(hours: 1));
      final container = makeContainer();
      container.listen(counting.provider, (_, __) {});
      await container.read(counting.provider.future);

      await backgroundTrip(container);

      expect(counting.calls(), 1);
    });

    test('an inactive blip alone does not refetch', () async {
      final counting = countingProvider();
      final container = makeContainer();
      container.listen(counting.provider, (_, __) {});
      await container.read(counting.provider.future);

      bus
        ..emit(AppLifecycleState.inactive)
        ..emit(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      await container.pump();

      expect(counting.calls(), 1);
    });

    test('nobody watching: marked stale, refetched when the screen returns',
        () async {
      // This is what keeps the mechanism cheap. Every provider that has ever
      // been read stays alive, so a resume must not fire a request for every
      // screen the user visited once.
      final counting = countingProvider();
      final container = makeContainer();
      await container.read(counting.provider.future);
      expect(counting.calls(), 1);

      await backgroundTrip(container);
      expect(counting.calls(), 1);

      expect(await container.read(counting.provider.future), 2);
    });

    test('keeps working across several background trips', () async {
      final counting = countingProvider();
      final container = makeContainer();
      container.listen(counting.provider, (_, __) {});
      await container.read(counting.provider.future);

      await backgroundTrip(container);
      await container.read(counting.provider.future);
      await backgroundTrip(container);

      expect(await container.read(counting.provider.future), 3);
    });

    test('stops listening once the provider is disposed', () async {
      final counting = countingProvider();
      final container = makeContainer();
      final subscription = container.listen(counting.provider, (_, __) {});
      await container.read(counting.provider.future);
      subscription.close();
      container.invalidate(counting.provider);
      await container.pump();

      await backgroundTrip(container);

      expect(counting.calls(), 1);
    });
  });

  group('appLifecycleBusProvider', () {
    testWidgets('forwards the real binding transitions', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final seen = <AppLifecycleState>[];
      container.read(appLifecycleBusProvider).stream.listen(seen.add);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(seen, [AppLifecycleState.paused, AppLifecycleState.resumed]);
    });
  });
}
