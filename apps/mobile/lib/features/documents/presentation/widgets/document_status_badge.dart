import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:navis_mobile/shared/widgets/navis_status_chip.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_pulse_budget.dart';
import 'package:navis_mobile/core/theme/tone.dart';

class DocumentStatusBadge extends StatelessWidget {
  const DocumentStatusBadge({super.key, required this.expiryDate});

  final DateTime expiryDate;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final status = NavisDateUtils.statusFor(expiryDate);
    final (NavisTone tone, String label) = switch (status) {
      DocExpiryStatus.expired => (NavisTone.critical, l.expired),
      DocExpiryStatus.critical => (NavisTone.critical, l.critical),
      DocExpiryStatus.warning => (NavisTone.caution, l.warning),
      DocExpiryStatus.ok => (NavisTone.positive, l.valid),
    };

    final shouldGlow =
        status == DocExpiryStatus.expired || status == DocExpiryStatus.critical;

    // A filled chip, not tinted text on a tinted wash. The wash version put
    // amber ink on cream for "warning", which is the one pairing on the light
    // canvas that has to be brown to be legible.
    //
    // No BackdropFilter either: this badge is drawn once per row, so a list of
    // ten documents paid ten blur passes a frame, on a page canvas where a blur
    // returns the pixels it was given. Same reasoning as NavisCard — it just
    // took longer to be noticed here, because the badge is small.
    Widget badge = NavisStatusChip(label: label, tone: tone);

    if (shouldGlow) {
      // Bounded: an endless shimmer repaints this badge every frame for the
      // whole life of the screen. The solid red chip keeps carrying the message
      // once it stops.
      badge = RepaintBoundary(
        child: badge
            .animate(
              onPlay: (controller) =>
                  controller.repeat(count: PulseBudget.urgent),
            )
            .shimmer(
              duration: 2000.ms,
              // A white sheen over the fill, since the chip is now solid.
              color: Colors.white.withValues(alpha: 0.28),
            ),
      );
    }

    return badge;
  }
}
