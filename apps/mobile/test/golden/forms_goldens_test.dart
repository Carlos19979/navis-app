@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/boat/data/boat_share_repository.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';
import 'package:navis_mobile/features/boat/presentation/screens/boat_form_screen.dart';
import 'package:navis_mobile/features/documents/presentation/providers/document_provider.dart';
import 'package:navis_mobile/features/documents/presentation/screens/document_form_screen.dart';
import 'package:navis_mobile/features/groups/presentation/screens/group_form_screen.dart';
import 'package:navis_mobile/features/logbook/presentation/providers/logbook_provider.dart';
import 'package:navis_mobile/features/logbook/presentation/screens/trip_edit_screen.dart';
import 'package:navis_mobile/features/regattas/data/repositories/regatta_repository.dart';
import 'package:navis_mobile/features/regattas/domain/entities/regatta.dart';
import 'package:navis_mobile/features/regattas/presentation/providers/regatta_provider.dart';
import 'package:navis_mobile/features/regattas/presentation/screens/regatta_detail_screen.dart';

import '../helpers/helpers.dart';
import 'golden_harness.dart';

class _MockRegattaRepository extends Mock implements RegattaRepository {}

/// The forms and the regatta detail: the screens this phase re-grouped by
/// heading instead of by card. A stack of cards around pairs of fields read as
/// nested boxes, and the fields are already framed — worth a baseline so the
/// next pass can see it.
void main() {
  setUpAll(() async {
    await loadTestFonts();
    // The regatta screen reads the signed-in user to tell owner from crew.
    await signInFakeUser();
  });

  Future<void> shot(
    WidgetTester tester,
    Widget screen,
    Type type,
    String name,
    Brightness brightness, {
    required List<Override> overrides,
  }) async {
    await pumpGolden(
      tester,
      screen,
      brightness: brightness,
      settle: false,
      overrides: overrides,
    );
    await expectLater(
      find.byType(type),
      matchesGoldenFile(goldenPath(name, brightness)),
    );
  }

  for (final brightness in Brightness.values) {
    testWidgets('boat form — ${brightness.name}', (tester) async {
      await shot(
        tester,
        const BoatFormScreen(boatId: 'boat-1'),
        BoatFormScreen,
        'boat_form',
        brightness,
        overrides: [
          boatProvider.overrideWith((ref, id) async => makeBoat(id: id)),
        ],
      );
    });

    testWidgets('trip edit — ${brightness.name}', (tester) async {
      await shot(
        tester,
        const TripEditScreen(tripId: 'trip-1'),
        TripEditScreen,
        'trip_edit',
        brightness,
        overrides: [
          tripProvider.overrideWith(
            (ref, id) async => makeTrip(engineHours: 3, fuelConsumedL: 48),
          ),
          boatMembersProvider.overrideWith((ref, id) async => const []),
        ],
      );
    });

    testWidgets('document form — ${brightness.name}', (tester) async {
      await shot(
        tester,
        const DocumentFormScreen(boatId: 'boat-1'),
        DocumentFormScreen,
        'document_form',
        brightness,
        overrides: [
          boatDocumentsProvider.overrideWith((ref, id) async => const []),
        ],
      );
    });

    testWidgets('club form — ${brightness.name}', (tester) async {
      await shot(
        tester,
        const GroupFormScreen(),
        GroupFormScreen,
        'group_form',
        brightness,
        overrides: const [],
      );
    });

    testWidgets('regatta detail — ${brightness.name}', (tester) async {
      await shot(
        tester,
        const RegattaDetailScreen(regattaId: 'regatta-1'),
        RegattaDetailScreen,
        'regatta_detail',
        brightness,
        overrides: [
          regattaRepositoryProvider.overrideWithValue(_MockRegattaRepository()),
          regattaProvider.overrideWith(
            (ref, id) async => makeRegatta(
              id: id,
              scheduledAt: DateTime(2026, 6, 15, 11),
            ),
          ),
          regattaParticipantsProvider.overrideWith(
            (ref, id) async => const <RegattaParticipant>[],
          ),
          boatMembersProvider.overrideWith((ref, id) async => const []),
        ],
      );
    });
  }
}
