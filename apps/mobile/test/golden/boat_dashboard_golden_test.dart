@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/features/boat/data/boat_share_repository.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';
import 'package:navis_mobile/features/boat/presentation/screens/boat_dashboard_screen.dart';
import 'package:navis_mobile/features/documents/presentation/providers/document_provider.dart';
import 'package:navis_mobile/features/weather/presentation/providers/weather_provider.dart';

import '../helpers/plan.dart';
import '../helpers/test_helpers.dart';
import 'golden_harness.dart';

class _FakeBoatsNotifier extends AsyncNotifier<List<Boat>>
    implements BoatsNotifier {
  _FakeBoatsNotifier(this._boats);
  final List<Boat> _boats;

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
  Future<void> deleteBoat(String id) async {}
}

void main() {
  setUpAll(loadTestFonts);

  final boats = [
    makeBoat(),
    makeBoat(
      id: 'boat-2',
      name: 'Sea Runner',
      type: 'motorboat',
      registration: 'ES-BCN-7-5678',
    ),
  ];

  for (final brightness in Brightness.values) {
    testWidgets('boat dashboard — ${brightness.name}', (tester) async {
      await pumpGolden(
        tester,
        const BoatDashboardScreen(),
        brightness: brightness,
        settle: false,
        overrides: [
          ...planOverrides(),
          boatsProvider.overrideWith(() => _FakeBoatsNotifier(boats)),
          sharedBoatsProvider.overrideWith((ref) async => const <Boat>[]),
          currentWeatherProvider.overrideWith((ref) async => makeWeather()),
          boatDocumentSummaryProvider.overrideWith(
            (ref, boatId) async =>
                const DocumentSummary(total: 3, ok: 2, warning: 1),
          ),
        ],
      );
      await expectLater(
        find.byType(BoatDashboardScreen),
        matchesGoldenFile(goldenPath('boat_dashboard', brightness)),
      );
    });
  }
}
