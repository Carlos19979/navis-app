import 'package:navis_mobile/app/routes.dart';

/// Deep links for readiness entries.
///
/// Push notifications carry a `{type, id}` payload that the notification
/// provider turns into a route. Readiness entries follow the same convention,
/// with one difference: the readiness endpoint returns no per-item id, so an
/// entry resolves to the boat-scoped screen that owns it — document and
/// safety-gear entries land on the boat's document list, maintenance entries on
/// its maintenance screen.
///
/// Returns null when the entry has no screen to open, so callers can leave the
/// row non-interactive instead of pushing a dead route.
String? readinessRoute({
  required String boatId,
  required String category,
  String ref = '',
}) {
  if (boatId.isEmpty) return null;
  if (ref == 'engine_service') return Routes.boatMaintenance(boatId);
  return switch (category) {
    'maintenance' => Routes.boatMaintenance(boatId),
    'documents' || 'safety_gear' => Routes.boatDocuments(boatId),
    _ => null,
  };
}
