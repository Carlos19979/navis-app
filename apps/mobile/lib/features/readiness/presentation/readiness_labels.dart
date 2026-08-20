/// Localized names and timing phrases for readiness entries.
///
/// Extracted from the readiness screen because Today needs the same strings:
/// its "coming up" block is the first three of the same `attention` list, and
/// two copies of this mapping would drift the moment the API grew a document
/// type.
library;

import 'package:navis_mobile/features/readiness/data/readiness_repository.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';

/// The localized name of an entry, by the API's `ref` value.
String readinessRefLabel(AppLocalizations l, String ref) => switch (ref) {
      'itb' => l.readinessRefItb,
      'insurance_rc' => l.readinessRefInsurance,
      'insurance_full' => l.readinessRefInsurance,
      'life_raft' => l.readinessRefLifeRaft,
      'extinguisher' => l.readinessRefExtinguisher,
      'flares' => l.readinessRefFlares,
      'first_aid' => l.readinessRefFirstAid,
      'medical_cert' => l.readinessRefMedicalCert,
      'radio_cert' => l.readinessRefRadioCert,
      'navigation_license' => l.readinessRefNavLicense,
      'engine_service' => l.readinessRefEngineService,
      _ => l.readinessRefDocument,
    };

/// The entry's own name when the API supplied one, else its type's name.
String readinessItemTitle(AppLocalizations l, ReadinessItem item) =>
    item.label.isNotEmpty ? item.label : readinessRefLabel(l, item.ref);

/// Human phrase for an entry's timing.
String readinessDaysLabel(AppLocalizations l, ReadinessItem item) {
  if (item.ref == 'engine_service') {
    switch (item.reason) {
      case 'no_plan':
        return l.readinessMaintNoPlan;
      case 'overdue':
        return l.readinessMaintOverdue;
      case 'pending':
        return l.readinessMaintPending;
      default:
        // due_soon: prefer the nearer of date/hours.
        if (item.hours != null && (item.days <= 0 || item.hours! < item.days)) {
          return l.readinessMaintInHours(item.hours!.round());
        }
        return l.readinessExpiresInDays(item.days);
    }
  }
  if (item.days < 0) return l.readinessExpired;
  return l.readinessExpiresInDays(item.days);
}
