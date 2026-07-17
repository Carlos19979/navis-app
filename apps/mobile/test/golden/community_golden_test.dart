@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/community/presentation/screens/community_screen.dart';
import 'package:navis_mobile/features/events/presentation/providers/event_provider.dart';
import 'package:navis_mobile/features/groups/data/repositories/group_repository.dart';
import 'package:navis_mobile/features/groups/domain/entities/group.dart';
import 'package:navis_mobile/features/groups/presentation/providers/group_provider.dart';

import '../helpers/plan.dart';
import '../helpers/test_helpers.dart';
import 'golden_harness.dart';

class _MockGroupRepository extends Mock implements GroupRepository {}

void main() {
  setUpAll(loadTestFonts);

  // Seeded-style regatta events (mirrors the demo seed data): a featured
  // major regatta plus a regular one. The regattas tab is the initial tab.
  final events = [
    makeEvent(),
    makeEvent(
      id: 'event-2',
      name: 'Trofeo Princesa Sofia',
      organizer: 'CNA',
      isFeatured: false,
    ),
  ];

  for (final brightness in Brightness.values) {
    testWidgets('community — ${brightness.name}', (tester) async {
      await pumpGolden(
        tester,
        const CommunityScreen(),
        brightness: brightness,
        settle: false,
        overrides: [
          ...planOverrides(),
          groupRepositoryProvider.overrideWithValue(_MockGroupRepository()),
          eventsProvider.overrideWith((ref) async => events),
          myGroupsProvider.overrideWith((ref) async => const <Group>[]),
          discoverGroupsProvider.overrideWith((ref) async => const <Group>[]),
        ],
      );
      await expectLater(
        find.byType(CommunityScreen),
        matchesGoldenFile(goldenPath('community', brightness)),
      );
    });
  }
}
