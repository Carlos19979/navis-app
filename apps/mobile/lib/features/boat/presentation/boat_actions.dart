import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/app/routes.dart';
import 'package:navis_mobile/features/billing/billing.dart';
import 'package:navis_mobile/features/billing/presentation/paywall_sheet.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/logbook/presentation/providers/trip_recording_provider.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';

/// Starting a trip and starting an anchor watch, in one place.
///
/// These two live here rather than on a screen because three screens offer
/// them — Today, the forecast and the chart — and each one carries real
/// policy: a crew permission, a plan tier, a paywall, and the rule that the
/// GPS stream has one owner at a time. Copied into three screens that policy
/// drifts, and the drift is invisible: every copy still *works*.
///
/// The forecast and the chart used to offer neither. That was the finding
/// behind this: the two tabs a sailor opens before leaving could tell them the
/// wind was perfect and give them no way to act on it.
class BoatActions {
  BoatActions._();

  /// Whether this boat's crew permissions allow recording at all. Owners
  /// always can; a guest may not, and then the action is *absent*, not
  /// disabled — a button that refuses is worse than no button.
  static bool canSail(Boat boat) => boat.permissions.canRecordTrips;

  /// What the sail action is called right now.
  ///
  /// Since the background-GPS work a recording survives leaving the map, so
  /// "already sailing" is an ordinary state, not an edge case — and calling the
  /// button «Zarpar» while a trip is running was telling the user to do
  /// something they had already done.
  static String sailLabel(AppLocalizations l, WidgetRef ref) =>
      ref.watch(tripRecordingProvider).isActive
          ? l.resumeTripAction
          : l.startTrip;

  /// Opens the pre-departure checklist, or the trip already in progress.
  static void sail(BuildContext context, WidgetRef ref, Boat boat) {
    final recording = ref.read(tripRecordingProvider);
    if (recording.isActive) {
      // The recording boat, not the active one: they can differ, and the trip
      // in progress is the one the user means.
      unawaited(context.push(Routes.boatRecord(recording.boatId ?? boat.id)));
      return;
    }
    unawaited(context.push(Routes.boatPrecheck(boat.id)));
  }

  /// Opens the anchor watch (Plus and up).
  ///
  /// Blocked while a trip is recording: both drive the GPS stream, and running
  /// them together is what the original guard existed to prevent.
  static Future<void> anchor(
    BuildContext context,
    WidgetRef ref,
    Boat boat,
  ) async {
    final l = AppLocalizations.of(context)!;
    if (ref.read(tripRecordingProvider).isActive) {
      NavisSnackbar.info(context, l.anchorTripActiveBlock);
      return;
    }
    if (!ref.read(effectiveTierProvider).canAnchorAlarm) {
      final ok = await showPaywall(
        context,
        ref,
        reason: l.paywallReasonAnchor,
        requiredTier: PlanTier.plus,
      );
      if (!ok || !context.mounted) return;
    }
    if (context.mounted) unawaited(context.push(Routes.boatAnchor(boat.id)));
  }

  /// The plan marker for the anchor action, or null when it is included.
  static String? anchorLock(AppLocalizations l, WidgetRef ref) =>
      ref.watch(effectiveTierProvider).canAnchorAlarm ? null : l.plusBadge;
}
