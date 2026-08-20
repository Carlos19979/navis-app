import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/core/utils/byte_utils.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/features/charts/domain/entities/chart_region.dart';
import 'package:navis_mobile/features/charts/presentation/providers/offline_charts_provider.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_async_view.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';
import 'package:navis_mobile/shared/widgets/navis_dialog.dart';
import 'package:navis_mobile/shared/widgets/navis_scaffold.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';

/// Manages the chart areas saved on this device: what they cost in storage,
/// and getting rid of the ones that are no longer sailed.
class OfflineChartsScreen extends ConsumerWidget {
  const OfflineChartsScreen({super.key});

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ChartRegion region,
  ) async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await NavisConfirmDialog.show(
      context,
      title: l.deleteArea,
      message: l.deleteAreaConfirm(region.name),
      confirmLabel: l.delete,
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    try {
      await ref.read(chartRegionsProvider.notifier).delete(region.id);
      if (context.mounted) NavisSnackbar.success(context, l.areaDeleted);
    } on Exception {
      if (context.mounted) NavisSnackbar.error(context, l.somethingWentWrong);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final regions = ref.watch(chartRegionsProvider);
    final storage = ref.watch(chartStorageBytesProvider).valueOrNull;

    return NavisScaffold(
      title: l.offlineCharts,
      showBack: true,
      body: NavisAsyncListView<ChartRegion>(
        value: regions,
        onRefresh: () => ref.read(chartRegionsProvider.notifier).reload(),
        emptyIcon: Icons.map_outlined,
        emptyMessage: l.noSavedAreas,
        emptyDescription: l.noSavedAreasDescription,
        header: Padding(
          padding: const EdgeInsets.only(bottom: Dimens.spaceMd),
          child: Text(
            storage == null
                ? l.offlineChartsIntro
                : '${l.offlineChartsIntro}\n'
                    '${l.chartStorageUsed(ByteUtils.format(storage))}',
            style: TextStyle(color: context.txtSecondary, fontSize: 13),
          ),
        ),
        itemBuilder: (context, region, index) => _RegionCard(
          region: region,
          onDelete: () => _delete(context, ref, region),
        ),
      ),
    );
  }
}

class _RegionCard extends StatelessWidget {
  const _RegionCard({required this.region, required this.onDelete});

  final ChartRegion region;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final incomplete = region.status != ChartRegionStatus.ready;

    return NavisCard(
      margin: const EdgeInsets.only(bottom: Dimens.spaceMd),
      child: Row(
        children: [
          Icon(
            incomplete ? Icons.cloud_off_outlined : Icons.map_outlined,
            color: incomplete ? context.caution : context.accent,
            size: Dimens.iconLg,
          ),
          const SizedBox(width: Dimens.spaceLg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  region.name,
                  style: TextStyle(
                    color: context.txtPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: Dimens.spaceXs),
                Text(
                  l.chartRegionDetail(
                    region.minZoom,
                    region.maxZoom,
                    ByteUtils.format(region.bytes),
                  ),
                  style: TextStyle(
                    color: context.txtSecondary,
                    fontSize: 12,
                  ),
                ),
                Text(
                  incomplete
                      ? '${l.chartRegionIncomplete} - '
                          '${NavisDateUtils.formatDate(region.createdAt)}'
                      : NavisDateUtils.formatDate(region.createdAt),
                  style: TextStyle(
                    color: incomplete ? context.caution : context.txtSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: context.critical),
            tooltip: l.deleteArea,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
