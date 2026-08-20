import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/network/connectivity_provider.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/charts/domain/entities/chart_region.dart';
import 'package:navis_mobile/features/charts/presentation/providers/offline_charts_provider.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';

/// Tells the helm what the chart under it actually is when there is no signal:
/// saved charts, or nothing saved for here. Renders nothing while online.
///
/// Deliberately its own banner rather than the app-wide NavisOfflineBanner:
/// on the water "offline" is the normal state, and what matters is whether the
/// map can still be trusted, not that a sync is pending.
class OfflineChartBanner extends ConsumerWidget {
  const OfflineChartBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(connectivityProvider)) return const SizedBox.shrink();

    final l = AppLocalizations.of(context)!;
    final regions = ref.watch(chartRegionsProvider).valueOrNull;
    final hasCharts = regions != null &&
        regions.any((r) => r.status != ChartRegionStatus.failed);
    final color = hasCharts ? context.accent : context.caution;

    return ClipRRect(
      borderRadius: BorderRadius.circular(Dimens.radiusMd),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: Dimens.blurOverlay,
          sigmaY: Dimens.blurOverlay,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimens.spaceMd,
            vertical: Dimens.spaceSm,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(Dimens.radiusMd),
            border: Border.all(
              color: color.withValues(alpha: 0.4),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasCharts ? Icons.offline_pin_outlined : Icons.cloud_off,
                size: Dimens.iconSm,
                color: color,
              ),
              const SizedBox(width: Dimens.spaceSm),
              Flexible(
                child: Text(
                  hasCharts
                      ? l.offlineChartsBanner
                      : l.offlineChartsBannerEmpty,
                  style: TextStyle(color: color, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
