@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/groups/data/repositories/group_repository.dart';
import 'package:navis_mobile/features/groups/domain/entities/group_member.dart';
import 'package:navis_mobile/features/groups/presentation/providers/group_provider.dart';
import 'package:navis_mobile/features/groups/presentation/screens/group_detail_screen.dart';
import 'package:navis_mobile/features/regattas/presentation/providers/regatta_provider.dart';

import '../helpers/supabase.dart';
import '../helpers/test_helpers.dart';
import 'golden_harness.dart';

class _MockGroupRepository extends Mock implements GroupRepository {}

void main() {
  setUpAll(() async {
    await loadTestFonts();
    // The screen resolves the current user against the Supabase session;
    // signing in as user-1 makes it the group owner (owner view).
    await signInFakeUser();
  });

  const groupId = 'group-1';

  const members = [
    GroupMember(
        userId: 'user-1', name: 'Carlos', role: 'owner', status: 'active'),
    GroupMember(
        userId: 'user-2', name: 'Maria', role: 'member', status: 'active'),
    GroupMember(
        userId: 'user-3', name: 'Jon', role: 'member', status: 'active'),
  ];

  for (final brightness in Brightness.values) {
    testWidgets('group detail — ${brightness.name}', (tester) async {
      await pumpGolden(
        tester,
        const GroupDetailScreen(groupId: groupId),
        brightness: brightness,
        settle: false,
        overrides: [
          groupRepositoryProvider.overrideWithValue(_MockGroupRepository()),
          groupProvider.overrideWith((ref, id) async => makeGroup()),
          groupMembersProvider.overrideWith((ref, id) async => members),
          groupRequestsProvider.overrideWith(
            (ref, id) async => const <GroupMember>[],
          ),
          groupRegattasProvider.overrideWith(
            (ref, id) async => [makeRegatta()],
          ),
        ],
      );
      await expectLater(
        find.byType(GroupDetailScreen),
        matchesGoldenFile(goldenPath('group_detail', brightness)),
      );
    });
  }
}
