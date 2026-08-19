@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/features/boat/data/boat_share_repository.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';
import 'package:navis_mobile/features/boat/presentation/screens/boat_detail_screen.dart';
import 'package:navis_mobile/features/readiness/data/readiness_repository.dart';
import 'package:navis_mobile/features/readiness/presentation/providers/readiness_provider.dart';

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

/// Enough of a breakdown for the readiness banner to render loaded. Without
/// this override the provider errors and the banner renders as nothing, so the
/// boat's headline status was missing from its own baseline.
Readiness _readiness() => const Readiness(
      score: 72,
      status: ReadinessStatus.attention,
      full: true,
      categories: [],
      attention: [
        ReadinessItem(
          category: 'documents',
          ref: 'insurance_rc',
          status: ReadinessStatus.attention,
          days: 12,
        ),
        ReadinessItem(
          category: 'safety_gear',
          ref: 'flares',
          status: ReadinessStatus.attention,
          days: 40,
        ),
      ],
    );

void main() {
  setUpAll(loadTestFonts);

  // makeBoat() has no photoUrl, so the header renders the deterministic
  // placeholder image instead of a network photo.
  final boat = makeBoat();

  for (final brightness in Brightness.values) {
    testWidgets('boat detail — ${brightness.name}', (tester) async {
      await pumpGolden(
        tester,
        BoatDetailScreen(boatId: boat.id),
        brightness: brightness,
        settle: false,
        overrides: [
          boatProvider.overrideWith((ref, id) async => boat),
          boatsProvider.overrideWith(() => _FakeBoatsNotifier([boat])),
          boatMembersProvider.overrideWith(
            (ref, id) async => [makeBoatMember()],
          ),
          boatReadinessProvider.overrideWith((ref, id) async => _readiness()),
        ],
      );
      await expectLater(
        find.byType(BoatDetailScreen),
        matchesGoldenFile(goldenPath('boat_detail', brightness)),
      );
    });
  }
}
