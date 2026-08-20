import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/features/boat/data/boat_share_repository.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';
import 'package:navis_mobile/features/documents/presentation/providers/document_provider.dart';
import 'package:navis_mobile/features/readiness/data/readiness_repository.dart';
import 'package:navis_mobile/features/readiness/presentation/providers/readiness_provider.dart';
import 'package:navis_mobile/features/weather/presentation/providers/weather_provider.dart';

import 'prefs.dart';
import 'test_helpers.dart';

/// A [BoatsNotifier] that just holds a list, and records deletions.
class FakeBoatsNotifier extends AsyncNotifier<List<Boat>>
    implements BoatsNotifier {
  FakeBoatsNotifier(this._boats);

  final List<Boat> _boats;

  /// Ids the screen asked to delete, so the destructive path can be asserted
  /// without a repository.
  final deleted = <String>[];

  @override
  Future<List<Boat>> build() async => _boats;
  @override
  Future<void> loadMore() async {}
  @override
  Future<void> refresh() async {}
  @override
  Future<Boat> createBoat(Boat boat) async => boat;
  @override
  Future<void> updateBoat(Boat boat) async {}
  @override
  Future<void> deleteBoat(String id) async => deleted.add(id);
}

class ErrorBoatsNotifier extends AsyncNotifier<List<Boat>>
    implements BoatsNotifier {
  @override
  Future<List<Boat>> build() async => throw Exception('Network error');
  @override
  Future<void> loadMore() async {}
  @override
  Future<void> refresh() async {}
  @override
  Future<Boat> createBoat(Boat boat) async => throw UnimplementedError();
  @override
  Future<void> updateBoat(Boat boat) async {}
  @override
  Future<void> deleteBoat(String id) async {}
}

/// A [BoatsNotifier] whose load never finishes, for the loading state.
class NeverCompleteBoatsNotifier extends AsyncNotifier<List<Boat>>
    implements BoatsNotifier {
  @override
  Future<List<Boat>> build() =>
      Future<List<Boat>>.delayed(const Duration(days: 1));
  @override
  Future<void> loadMore() async {}
  @override
  Future<void> refresh() async {}
  @override
  Future<Boat> createBoat(Boat boat) async => throw UnimplementedError();
  @override
  Future<void> updateBoat(Boat boat) async {}
  @override
  Future<void> deleteBoat(String id) async {}
}

Readiness fakeReadiness({
  int score = 88,
  ReadinessStatus status = ReadinessStatus.ready,
  List<ReadinessItem> attention = const [],
}) =>
    Readiness(
      score: score,
      status: status,
      full: true,
      categories: const [],
      attention: attention,
    );

/// The minimum world Today needs to render.
///
/// It is the home screen, so it composes more providers than any other single
/// screen: the boat list, the shared list, the active-boat preference, the
/// readiness summary, the document summary and the forecast. A test that only
/// cares about one row of it should not have to know that — pass what matters
/// and let the rest be quiet defaults.
Future<List<Override>> todayOverrides({
  List<Boat>? boats,
  List<Boat> shared = const [],
  BoatsNotifier Function()? notifier,
  Readiness? readiness,
  DocumentSummary summary = const DocumentSummary(),
  Map<String, Object> prefs = const {},
}) async {
  final resolved = boats ?? [makeBoat()];
  return [
    await prefsOverride(prefs),
    boatsProvider.overrideWith(
      notifier ?? () => FakeBoatsNotifier(resolved),
    ),
    sharedBoatsProvider.overrideWith((ref) async => shared),
    // No location fix in a widget test, so the conditions block stays out of
    // the tree unless a test supplies a forecast itself.
    weatherOverviewProvider.overrideWith((ref) async => null),
    currentWeatherProvider.overrideWith((ref) async => null),
    boatReadinessProvider.overrideWith(
      (ref, id) async => readiness ?? fakeReadiness(),
    ),
    boatDocumentSummaryProvider.overrideWith((ref, id) async => summary),
  ];
}
