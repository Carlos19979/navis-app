import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/boat/data/boat_share_repository.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat_permissions.dart';
import 'package:navis_mobile/features/boat/presentation/widgets/boat_members_sheet.dart';

import '../../helpers/helpers.dart';

class _MockShareRepository extends Mock implements BoatShareRepository {}

void main() {
  const boatId = 'boat-1';

  setUpAll(() => registerFallbackValue(const BoatPermissions.none()));

  late _MockShareRepository repo;

  setUp(() => repo = _MockShareRepository());

  /// A button that opens the sheet, so the sheet is mounted the way the boat
  /// detail screen mounts it (and torn down the same way).
  Widget subject() {
    return buildTestAppWithScaffold(
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showBoatMembersSheet(context, boatId: boatId),
          child: const Text('open'),
        ),
      ),
      overrides: [boatShareRepositoryProvider.overrideWithValue(repo)],
    );
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('lists each member with a count of what they can do',
      (tester) async {
    when(() => repo.listMembers(boatId)).thenAnswer(
      (_) async => [
        BoatMember(
          userId: 'u-2',
          name: 'Maria',
          permissions: const BoatPermissions.none()
              .copyWith(canRecordTrips: true, canViewDocuments: true),
        ),
      ],
    );

    await tester.pumpWidget(subject());
    await openSheet(tester);

    expect(find.text('Crew and permissions'), findsOneWidget);
    expect(find.text('Maria'), findsOneWidget);
    expect(find.text('2 permissions'), findsOneWidget);
    expect(find.text("You haven't shared with anyone yet."), findsNothing);
  });

  testWidgets('a member who joined after the app started still shows up',
      (tester) async {
    // The regression: the owner's device has no way to learn about a join, so
    // a cached empty list kept showing "not shared with anyone yet". The
    // provider is autoDispose, so re-opening the sheet asks the server again.
    var call = 0;
    when(() => repo.listMembers(boatId)).thenAnswer((_) async {
      call++;
      if (call == 1) return const <BoatMember>[];
      return const [
        BoatMember(
          userId: 'u-2',
          name: 'Maria',
          permissions: BoatPermissions.none(),
        ),
      ];
    });

    await tester.pumpWidget(subject());
    await openSheet(tester);
    expect(find.text("You haven't shared with anyone yet."), findsOneWidget);

    // Close and re-open, as the owner would after being told someone joined.
    Navigator.of(tester.element(find.text('Crew and permissions'))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await openSheet(tester);

    expect(find.text('Maria'), findsOneWidget);
    expect(find.text("You haven't shared with anyone yet."), findsNothing);
    verify(() => repo.listMembers(boatId)).called(2);
  });

  testWidgets('the refresh action re-asks the server', (tester) async {
    when(() => repo.listMembers(boatId))
        .thenAnswer((_) async => const <BoatMember>[]);

    await tester.pumpWidget(subject());
    await openSheet(tester);

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    verify(() => repo.listMembers(boatId)).called(2);
  });

  testWidgets('toggling a permission is sent and reverts if it is refused',
      (tester) async {
    when(() => repo.listMembers(boatId)).thenAnswer(
      (_) async => const [
        BoatMember(
          userId: 'u-2',
          name: 'Maria',
          permissions: BoatPermissions.none(),
        ),
      ],
    );
    when(() => repo.setMemberPermissions(any(), any(), any()))
        .thenAnswer((_) async => throw Exception('boom'));

    await tester.pumpWidget(subject());
    await openSheet(tester);

    await tester.tap(find.text('Maria'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Record trips'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final captured = verify(
      () => repo.setMemberPermissions(boatId, 'u-2', captureAny()),
    ).captured.single as BoatPermissions;
    expect(captured.canRecordTrips, isTrue);

    // Refused: the switch must not keep claiming a permission the member
    // does not have.
    expect(find.text('0 permissions'), findsOneWidget);
  });

  testWidgets('an empty crew offers the share flow', (tester) async {
    when(() => repo.listMembers(boatId))
        .thenAnswer((_) async => const <BoatMember>[]);
    var shared = false;

    await tester.pumpWidget(
      buildTestAppWithScaffold(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showBoatMembersSheet(
              context,
              boatId: boatId,
              onShare: () => shared = true,
            ),
            child: const Text('open'),
          ),
        ),
        overrides: [boatShareRepositoryProvider.overrideWithValue(repo)],
      ),
    );
    await openSheet(tester);

    await tester.tap(find.text('Share boat'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(shared, isTrue);
  });
}
