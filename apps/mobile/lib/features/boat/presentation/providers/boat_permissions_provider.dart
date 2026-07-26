import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/network/session_provider.dart';
import 'package:navis_mobile/features/boat/data/boat_share_repository.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat_permissions.dart';

/// The single source of truth for what the current user may do on a boat.
///
/// Every screen that guards an action on a boat permission reads this, rather
/// than each one reaching into `boatProvider(id).permissions`: the boat is
/// cached offline and can be stale, while this is a direct read of the flags
/// the API enforces on the write paths.
///
/// `autoDispose` so entering a screen re-asks — the owner granting a permission
/// happens on the owner's device, and the member's app has no other way to
/// learn about it.
///
/// Errors are **not** swallowed into a permissive default. A caller with no
/// access gets a 404 here, and an unreachable server is not a grant; use
/// [BoatPermissionsX.grants] so both read as "blocked".
final boatPermissionsProvider = FutureProvider.autoDispose
    .family<BoatPermissions, String>((ref, boatId) async {
  // Permissions are per requester: rebuild when the signed-in user changes so
  // one account never inherits another's cached answer.
  ref.watch(sessionUserIdProvider);
  return ref.read(boatShareRepositoryProvider).effectivePermissions(boatId);
});

/// Fail-closed reads of a permission set that may still be loading.
extension BoatPermissionsX on AsyncValue<BoatPermissions> {
  /// Whether [area] is known to be granted.
  ///
  /// Loading and error both answer `false`: assuming "allowed" while we don't
  /// know is what let a user record an entire trip, or fill in a whole
  /// document, and only then lose it to a 403 on save.
  bool grants(BoatPermissionArea area) => switch (this) {
        AsyncData(:final value) => area.isGrantedIn(value),
        _ => false,
      };

  /// Whether the answer is still unknown (loading, or a failed lookup).
  /// A blocked action shows a different reason in that case: "we could not
  /// check" is not the same message as "the owner did not grant this".
  bool get isUnresolved => this is! AsyncData<BoatPermissions>;
}
