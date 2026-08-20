import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/logbook/data/repositories/trip_repository.dart';
import 'package:navis_mobile/features/logbook/presentation/providers/logbook_provider.dart';
import 'package:navis_mobile/features/logbook/presentation/screens/trip_detail_screen.dart';

import '../../helpers/helpers.dart';

class MockTripRepository extends Mock implements TripRepository {}

/// Trip sharing did nothing at all on the tester's phone — neither option.
///
/// The cause was a missing `sharePositionOrigin`. iOS presents the share sheet
/// as a popover and since iOS 26 rejects a null source rect on iPhone too, so
/// `Share.share()` without it throws and no sheet ever appears. Boat sharing
/// worked precisely because that one call site passed the origin; these tests
/// pin the same requirement on the trip screen, for both options.
void main() {
  const tripId = 'trip-1';
  const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

  late List<MethodCall> shareCalls;
  late MockTripRepository repository;

  setUp(() {
    shareCalls = [];
    repository = MockTripRepository();
  });

  void interceptShareSheet(WidgetTester tester) {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(shareChannel, (call) async {
      shareCalls.add(call);
      return 'dev.fluttercommunity.plus/share/success';
    });
    addTearDown(() => messenger.setMockMethodCallHandler(shareChannel, null));
  }

  Map<Object?, Object?> args() =>
      shareCalls.single.arguments as Map<Object?, Object?>;

  Future<void> pump(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> openScreen(WidgetTester tester) async {
    setPhoneSize(tester);
    await tester.pumpWidget(
      buildTestApp(
        const TripDetailScreen(tripId: tripId),
        overrides: [
          tripProvider.overrideWith(
            (ref, id) async => makeTrip(canManage: true),
          ),
          tripRepositoryProvider.overrideWithValue(repository),
        ],
      ),
    );
    await pump(tester);
    await tester.tap(find.byTooltip('Share trip'));
    await pump(tester);
  }

  void expectUsableOrigin() {
    final a = args();
    for (final key in ['originX', 'originY', 'originWidth', 'originHeight']) {
      expect(a[key], isNotNull, reason: '$key must be sent');
    }
    // A zero-sized rect is as unusable to UIKit as a null one.
    expect((a['originWidth']! as num) > 0, isTrue);
    expect((a['originHeight']! as num) > 0, isTrue);
  }

  testWidgets('sharing the summary reaches the OS sheet with a source rect',
      (tester) async {
    interceptShareSheet(tester);
    await openScreen(tester);

    await tester.tap(find.text('Share summary'));
    await pump(tester);

    expect(shareCalls, hasLength(1));
    expect(shareCalls.single.method, 'share');
    expect(args()['text'], contains('Palma de Mallorca'));
    expectUsableOrigin();
  });

  testWidgets('sharing a link asks the API for it and shares the URL',
      (tester) async {
    when(() => repository.shareTrip(tripId))
        .thenAnswer((_) async => 'https://navis.example/public/trips/abc/view');
    interceptShareSheet(tester);
    await openScreen(tester);

    await tester.tap(find.text('Share link'));
    await pump(tester);

    verify(() => repository.shareTrip(tripId)).called(1);
    expect(shareCalls, hasLength(1));
    expect(args()['text'], contains('https://navis.example/public/trips/abc'));
    expectUsableOrigin();
  });

  testWidgets('a link the server refuses says so instead of failing silently',
      (tester) async {
    when(() => repository.shareTrip(tripId)).thenThrow(Exception('403'));
    interceptShareSheet(tester);
    await openScreen(tester);

    await tester.tap(find.text('Share link'));
    await pump(tester);

    expect(shareCalls, isEmpty);
    expect(find.text("The link couldn't be created"), findsOneWidget);
  });

  testWidgets('a trip the user may not change offers no write actions',
      (tester) async {
    setPhoneSize(tester);
    await tester.pumpWidget(
      buildTestApp(
        const TripDetailScreen(tripId: tripId),
        overrides: [
          tripProvider.overrideWith(
            (ref, id) async => makeTrip(canManage: false),
          ),
          tripRepositoryProvider.overrideWithValue(repository),
        ],
      ),
    );
    await pump(tester);

    // The crew member who hit "trip not found" was tapping a delete button that
    // was never theirs to press.
    expect(find.byTooltip('Delete trip'), findsNothing);
    expect(find.byTooltip('Edit trip'), findsNothing);
    expect(find.byTooltip('Share trip'), findsNothing);
    expect(
      find.byTooltip(
        'Read-only trip: only whoever recorded it, or the boat\'s owner, '
        'can change it.',
      ),
      findsOneWidget,
    );
  });
}
