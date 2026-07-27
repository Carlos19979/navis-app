import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/features/boat/domain/entities/boat_permissions.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_permissions_provider.dart';

void main() {
  group('BoatPermissions', () {
    test('defaults to nothing granted', () {
      // The whole point: an unspecified permission set is not a licence.
      const perms = BoatPermissions();
      expect(perms.canRecordTrips, isFalse);
      expect(perms.canViewDocuments, isFalse);
      expect(perms.canManageDocuments, isFalse);
      expect(perms.canManageMaintenance, isFalse);
      expect(perms.canManageExpenses, isFalse);
      expect(perms.grantedCount, 0);
      expect(perms, const BoatPermissions.none());
    });

    test('all() grants every area', () {
      const perms = BoatPermissions.all();
      expect(perms.grantedCount, BoatPermissionArea.values.length);
      for (final area in BoatPermissionArea.values) {
        expect(area.isGrantedIn(perms), isTrue, reason: area.name);
      }
    });

    test('fromJson reads a missing flag as not granted', () {
      // The server sends all five; anything else is an unknown payload and
      // must not be read as a grant.
      final perms = BoatPermissions.fromJson({'can_record_trips': true});
      expect(perms.canRecordTrips, isTrue);
      expect(perms.canViewDocuments, isFalse);
      expect(perms.grantedCount, 1);
    });

    test('round-trips through json', () {
      const perms =
          BoatPermissions(canRecordTrips: true, canViewDocuments: true);
      expect(BoatPermissions.fromJson(perms.toJson()), perms);
    });

    test('each area maps to its own flag', () {
      const perms = BoatPermissions(canManageExpenses: true);
      expect(BoatPermissionArea.manageExpenses.isGrantedIn(perms), isTrue);
      expect(BoatPermissionArea.manageMaintenance.isGrantedIn(perms), isFalse);
      expect(BoatPermissionArea.recordTrips.isGrantedIn(perms), isFalse);
      expect(BoatPermissionArea.viewDocuments.isGrantedIn(perms), isFalse);
      expect(BoatPermissionArea.manageDocuments.isGrantedIn(perms), isFalse);
    });
  });

  group('boatPermissionsProvider', () {
    test('resolves the effective permission set for a boat', () async {
      final container = ProviderContainer(
        overrides: [
          boatPermissionsProvider.overrideWith(
            (ref, id) async =>
                const BoatPermissions.none().copyWith(canRecordTrips: true),
          ),
        ],
      );
      addTearDown(container.dispose);

      final perms =
          await container.read(boatPermissionsProvider('boat-1').future);
      expect(perms.canRecordTrips, isTrue);
      expect(perms.canManageExpenses, isFalse);
    });

    test('is scoped per boat id', () async {
      final container = ProviderContainer(
        overrides: [
          boatPermissionsProvider.overrideWith(
            (ref, id) async => id == 'mine'
                ? const BoatPermissions.all()
                : const BoatPermissions.none(),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        (await container.read(boatPermissionsProvider('mine').future))
            .grantedCount,
        5,
      );
      expect(
        (await container.read(boatPermissionsProvider('theirs').future))
            .grantedCount,
        0,
      );
    });
  });

  group('BoatPermissionsX fails closed', () {
    test('loading grants nothing', () {
      const state = AsyncLoading<BoatPermissions>();
      for (final area in BoatPermissionArea.values) {
        expect(state.grants(area), isFalse, reason: area.name);
      }
      expect(state.isUnresolved, isTrue);
    });

    test('a failed lookup grants nothing', () {
      final state =
          AsyncError<BoatPermissions>(Exception('offline'), StackTrace.empty);
      for (final area in BoatPermissionArea.values) {
        expect(state.grants(area), isFalse, reason: area.name);
      }
      expect(state.isUnresolved, isTrue);
    });

    test('data grants exactly what the server said', () {
      const state = AsyncData(
        BoatPermissions(canRecordTrips: true, canViewDocuments: true),
      );
      expect(state.grants(BoatPermissionArea.recordTrips), isTrue);
      expect(state.grants(BoatPermissionArea.viewDocuments), isTrue);
      expect(state.grants(BoatPermissionArea.manageDocuments), isFalse);
      expect(state.isUnresolved, isFalse);
    });
  });
}
