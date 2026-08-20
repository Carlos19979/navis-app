import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:navis_mobile/core/theme/app_typography.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_pulse_budget.dart';

class DocumentStatusBadge extends StatelessWidget {
  const DocumentStatusBadge({super.key, required this.expiryDate});

  final DateTime expiryDate;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final status = NavisDateUtils.statusFor(expiryDate);
    final (Color color, String label) = switch (status) {
      DocExpiryStatus.expired => (context.critical, l.expired),
      DocExpiryStatus.critical => (context.critical, l.critical),
      DocExpiryStatus.warning => (context.caution, l.warning),
      DocExpiryStatus.ok => (context.positive, l.valid),
    };

    final shouldGlow =
        status == DocExpiryStatus.expired || status == DocExpiryStatus.critical;

    // No BackdropFilter. This badge is drawn once per row: a document list of
    // ten paid ten blur passes a frame, on a page canvas where a blur returns
    // the pixels it was given. Same reasoning as NavisCard — it just took
    // longer to be noticed here, because the badge is small.
    Widget badge = DecoratedBox(
      decoration: BoxDecoration(
        color: context.wash(color),
        borderRadius: BorderRadius.circular(Dimens.radiusPill),
        border: Border.all(color: context.washBorder(color)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Dimens.spaceMd,
          vertical: Dimens.spaceXs,
        ),
        child: Text(
          label,
          style: NavisType.caption.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );

    if (shouldGlow) {
      // Bounded: an endless shimmer repaints this badge — and the blurred
      // layer it sits on — every frame for the whole life of the screen. The
      // red border and glow keep carrying the message once it stops.
      badge = RepaintBoundary(
        child: badge
            .animate(
              onPlay: (controller) =>
                  controller.repeat(count: PulseBudget.urgent),
            )
            .shimmer(
              duration: 2000.ms,
              color: color.withValues(alpha: 0.15),
            ),
      );
    }

    return badge;
  }
}
