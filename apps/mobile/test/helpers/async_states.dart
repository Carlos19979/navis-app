import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_shimmer.dart';

import 'pumping.dart';

/// Runs the standard 4-state matrix (loading / error / empty / populated) for
/// a screen backed by one async provider.
///
/// [build] receives the provider override for the state under test and must
/// return the fully wrapped test app. [override] adapts a future factory into
/// that provider's override (e.g.
/// `(fetch) => myProvider.overrideWith((ref) => fetch())`).
void runAsyncStateMatrix<T>({
  required String screen,
  required Widget Function(Override) build,
  required Override Function(Future<T> Function()) override,
  required T empty,
  required T populated,
  required Finder Function() emptyFinder,
  required Finder Function() populatedFinder,
  Finder Function()? loadingFinder,
  Finder Function()? errorFinder,
}) {
  group('$screen async states', () {
    testWidgets('loading shows a placeholder', (tester) async {
      setPhoneSize(tester);
      final completer = Completer<T>();
      await tester.pumpWidget(build(override(() => completer.future)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(loadingFinder?.call() ?? find.byType(NavisShimmer), findsWidgets);

      // The provider future never completes: dispose and drain timers.
      await drain(tester);
    });

    testWidgets('error shows the error state', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        build(override(() async => throw Exception('boom'))),
      );
      await pumpScreen(tester);

      expect(
        errorFinder?.call() ?? find.byType(NavisErrorWidget),
        findsWidgets,
      );
    });

    testWidgets('empty shows the empty state', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(build(override(() async => empty)));
      await pumpScreen(tester);

      expect(emptyFinder(), findsWidgets);
    });

    testWidgets('populated shows the data', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(build(override(() async => populated)));
      await pumpScreen(tester);

      expect(populatedFinder(), findsWidgets);
    });
  });
}
