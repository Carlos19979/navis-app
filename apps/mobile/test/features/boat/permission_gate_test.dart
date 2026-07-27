import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/core/error/exceptions.dart';
import 'package:navis_mobile/features/boat/data/permission_errors.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat_permissions.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_permissions_provider.dart';
import 'package:navis_mobile/features/boat/presentation/widgets/permission_gate.dart';

import '../../helpers/helpers.dart';

/// Exactly what `ApiClient`'s error interceptor hands to a repository: a
/// [DioException] whose `error` is a [ServerException] carrying the status.
DioException apiError(int statusCode) => DioException(
      requestOptions: RequestOptions(path: '/api/v1/trips'),
      response: Response<void>(
        requestOptions: RequestOptions(path: '/api/v1/trips'),
        statusCode: statusCode,
      ),
      error: ServerException(message: 'FORBIDDEN', statusCode: statusCode),
    );

void main() {
  const boatId = 'boat-1';

  Widget subject({
    required BoatPermissionArea area,
    BoatPermissions? permissions,
    Object? error,
  }) {
    return buildTestAppWithScaffold(
      BoatPermissionGate(
        boatId: boatId,
        area: area,
        child: const Text('the action'),
      ),
      overrides: [
        boatPermissionsProvider.overrideWith((ref, id) {
          if (error != null) return Future<BoatPermissions>.error(error);
          if (permissions == null) return Completer<BoatPermissions>().future;
          return Future.value(permissions);
        }),
      ],
    );
  }

  testWidgets('renders the action when the permission is granted',
      (tester) async {
    await tester.pumpWidget(
      subject(
        area: BoatPermissionArea.recordTrips,
        permissions: const BoatPermissions(canRecordTrips: true),
      ),
    );
    await tester.pump();

    expect(find.text('the action'), findsOneWidget);
    expect(find.byType(BlockedActionCard), findsNothing);
  });

  testWidgets('blocks with the reason and who to ask when denied',
      (tester) async {
    await tester.pumpWidget(
      subject(
        area: BoatPermissionArea.recordTrips,
        permissions: const BoatPermissions.none(),
      ),
    );
    await tester.pump();

    expect(find.text('the action'), findsNothing);
    expect(find.byType(BlockedActionCard), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    expect(find.text('Action unavailable'), findsOneWidget);
    expect(find.text('You cannot record trips on this boat.'), findsOneWidget);
    expect(
      find.text('Ask the boat owner to grant you this permission.'),
      findsOneWidget,
    );
  });

  testWidgets('each area explains itself', (tester) async {
    const expected = {
      BoatPermissionArea.viewDocuments: "You cannot see this boat's documents.",
      BoatPermissionArea.manageDocuments:
          "You cannot add or edit this boat's documents.",
      BoatPermissionArea.manageMaintenance:
          "You cannot manage this boat's maintenance.",
      BoatPermissionArea.manageExpenses:
          "You cannot manage this boat's expenses.",
    };
    for (final entry in expected.entries) {
      await tester.pumpWidget(
        subject(area: entry.key, permissions: const BoatPermissions.none()),
      );
      await tester.pump();
      expect(find.text(entry.value), findsOneWidget, reason: entry.key.name);
    }
  });

  testWidgets('while loading the action is not offered', (tester) async {
    await tester.pumpWidget(subject(area: BoatPermissionArea.recordTrips));
    await tester.pump();

    // Neither allowed nor blamed on the owner: nothing is known yet.
    expect(find.text('the action'), findsNothing);
    expect(find.byType(BlockedActionCard), findsNothing);
  });

  testWidgets('a failed lookup blocks and offers a retry', (tester) async {
    await tester.pumpWidget(
      subject(
          area: BoatPermissionArea.recordTrips, error: Exception('offline')),
    );
    await tester.pump();

    expect(find.text('the action'), findsNothing);
    expect(
      find.text('Your permissions on this boat could not be checked.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    // Not the owner's fault, so it does not tell the user to go ask them.
    expect(
      find.text('Ask the boat owner to grant you this permission.'),
      findsNothing,
    );
  });

  testWidgets('a custom blocked widget replaces the card', (tester) async {
    await tester.pumpWidget(
      buildTestAppWithScaffold(
        const BoatPermissionGate(
          boatId: boatId,
          area: BoatPermissionArea.manageExpenses,
          blocked: Text('hidden instead'),
          child: Text('the action'),
        ),
        overrides: [
          boatPermissionsProvider.overrideWith(
            (ref, id) async => const BoatPermissions.none(),
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('hidden instead'), findsOneWidget);
    expect(find.byType(BlockedActionCard), findsNothing);
  });

  group('isPermissionDeniedError', () {
    test('recognises the API 403 that the interceptor wraps', () {
      expect(isPermissionDeniedError(apiError(403)), isTrue);
      // Also when the ServerException arrives unwrapped.
      expect(
        isPermissionDeniedError(
          const ServerException(message: 'FORBIDDEN', statusCode: 403),
        ),
        isTrue,
      );
    });

    test('leaves other failures to the generic message', () {
      expect(isPermissionDeniedError(apiError(500)), isFalse);
      expect(isPermissionDeniedError(apiError(404)), isFalse);
      expect(isPermissionDeniedError(Exception('boom')), isFalse);
    });
  });
}
