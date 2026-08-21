import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_status_badge.dart';

class DocumentStatusBadge extends StatelessWidget {
  const DocumentStatusBadge({super.key, required this.expiryDate});

  final DateTime expiryDate;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final status = NavisDateUtils.statusFor(expiryDate);
    final (Color color, String label) = switch (status) {
      DocExpiryStatus.expired => (AppColors.red, l.expired),
      DocExpiryStatus.critical => (AppColors.red, l.critical),
      DocExpiryStatus.warning => (AppColors.amber, l.warning),
      DocExpiryStatus.ok => (AppColors.green, l.valid),
    };

    return NavisStatusBadge(
      label: label,
      color: color,
      glow: status == DocExpiryStatus.expired ||
          status == DocExpiryStatus.critical,
    );
  }
}
