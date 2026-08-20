import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/core/deeplinks/join_deep_link.dart';
import 'package:navis_mobile/features/boat/data/boat_share_repository.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';
import 'package:navis_mobile/features/documents/presentation/providers/document_provider.dart';
import 'package:navis_mobile/features/weather/presentation/providers/weather_provider.dart';

import '../../helpers/helpers.dart';
import 'package:navis_mobile/features/boat/presentation/screens/today_screen.dart';

class MockBoatShareRepository extends Mock implements BoatShareRepository {}

class _EmptyBoatsNotifier extends AsyncNotifier<List<Boat>>
    implements BoatsNotifier {
  @override
  Future<List<Boat>> build() async => const [];
  @override
  Future<void> loadMore() async {}
  @override
  Future<void> refresh() async {}
  @override
  Future<Boat> createBoat(Boat boat) async => boat;
  @override
  Future<void> updateBoat(Boat boat) async {}
  @override
  Future<void> deleteBoat(String id) async {}
}

/// An invite link that opens the app has to end in the user actually joining.
/// Before this the app registered `navis://join` nowhere and did nothing with
/// it, so the link in every shared message was decoration.
void main() {
  const code = 'EZHT4CNG';

  late MockBoatShareRepository shareRepository;

  setUp(() {
    shareRepository = MockBoatShareRepository();
    when(() => shareRepository.joinBoat(any())).thenAnswer((_) async {});
    when(() => shareRepository.listShared()).thenAnswer((_) async => const []);
  });

  Widget subject({String? pendingCode}) => buildRoutedTestApp(
        const TodayScreen(),
        overrides: [
          boatsProvider.overrideWith(_EmptyBoatsNotifier.new),
          boatShareRepositoryProvider.overrideWithValue(shareRepository),
          if (pendingCode != null)
            pendingJoinCodeProvider.overrideWith((ref) => pendingCode),
          currentWeatherProvider.overrideWith((ref) async => null),
          boatDocumentSummaryProvider.overrideWith(
            (ref, boatId) async => const DocumentSummary(),
          ),
        ],
      );

  testWidgets('a code waiting from before the screen existed is still offered',
      (tester) async {
    setPhoneSize(tester);
    // The cold-start case: the link is handled while the app is still starting,
    // so by the time this screen builds the code is already there and never
    // "changes" again.
    await tester.pumpWidget(subject(pendingCode: code));
    await tester.pumpAndSettle();

    expect(find.textContaining(code), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Join'));
    await tester.pumpAndSettle();

    verify(() => shareRepository.joinBoat(code)).called(1);
  });

  testWidgets('a code arriving while the screen is open is offered too',
      (tester) async {
    setPhoneSize(tester);
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(TodayScreen)),
    );
    container.read(pendingJoinCodeProvider.notifier).state = code;
    await tester.pumpAndSettle();

    expect(find.textContaining(code), findsOneWidget);
  });

  testWidgets('declining the invite joins nothing and does not ask again',
      (tester) async {
    setPhoneSize(tester);
    await tester.pumpWidget(subject(pendingCode: code));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    verifyNever(() => shareRepository.joinBoat(any()));
    expect(find.textContaining(code), findsNothing);
  });
}
