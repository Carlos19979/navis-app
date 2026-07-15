import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/core/database/local_database.dart';
import 'package:navis_mobile/core/database/mutation_queue.dart';
import 'package:navis_mobile/core/network/connectivity_provider.dart';
import 'package:navis_mobile/shared/widgets/navis_offline_banner.dart';

import '../helpers/helpers.dart';

class MockLocalDatabase extends Mock implements LocalDatabase {}

void main() {
  late MockLocalDatabase db;
  late FakeConnectivityNotifier connectivity;

  setUp(() {
    db = MockLocalDatabase();
    when(db.getPendingMutationCount).thenAnswer((_) async => 0);
    connectivity = FakeConnectivityNotifier();
  });

  Widget app() {
    return buildTestApp(
      const NavisOfflineBanner(child: SizedBox.expand()),
      overrides: [
        connectivityProvider.overrideWith((ref) => connectivity),
        // Real notifier over a mocked database: no platform channels, and
        // the pending count comes from getPendingMutationCount.
        mutationQueueProvider.overrideWith(
          (ref) => MutationQueueNotifier(db: db, ref: ref),
        ),
      ],
    );
  }

  testWidgets('is hidden when online with no pending mutations',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.cloud_off_rounded), findsNothing);
    expect(find.byIcon(Icons.sync_rounded), findsNothing);
    expect(find.text('No internet connection'), findsNothing);
  });

  testWidgets('is visible with the offline message when offline',
      (tester) async {
    connectivity.setOnline(false);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    expect(find.text('No internet connection'), findsOneWidget);
  });

  testWidgets('appears when going offline and hides when back online',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.cloud_off_rounded), findsNothing);

    connectivity.setOnline(false);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    expect(find.text('No internet connection'), findsOneWidget);

    connectivity.setOnline(true);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.cloud_off_rounded), findsNothing);
    expect(find.text('No internet connection'), findsNothing);
  });

  testWidgets('shows the pending count while offline with queued changes',
      (tester) async {
    when(db.getPendingMutationCount).thenAnswer((_) async => 2);
    connectivity.setOnline(false);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    expect(find.text('Offline • 2 pending'), findsOneWidget);
  });

  testWidgets('shows the syncing state when online with queued changes',
      (tester) async {
    when(db.getPendingMutationCount).thenAnswer((_) async => 3);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.sync_rounded), findsOneWidget);
    expect(find.text('Syncing 3 changes…'), findsOneWidget);
  });
}
