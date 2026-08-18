import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/core/utils/byte_utils.dart';
import 'package:navis_mobile/features/charts/data/chart_region_downloader.dart';
import 'package:navis_mobile/features/charts/data/tile_math.dart';
import 'package:navis_mobile/features/charts/presentation/providers/offline_charts_provider.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';
import 'package:navis_mobile/shared/widgets/navis_selectable_card.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';

/// How deep the download goes. Standard is enough to pilot a coastline;
/// detailed doubles the zoom levels and roughly quadruples the weight, which is
/// only worth it for a harbour approach.
enum ChartDetail {
  standard(14),
  fine(16);

  const ChartDetail(this.maxZoom);

  final int maxZoom;
}

/// Offers the visible chart area for offline download, and reports on what is
/// already saved.
Future<void> showOfflineChartsSheet(
  BuildContext context, {
  required TileBox box,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: context.dialogSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(Dimens.radiusXxl),
      ),
    ),
    builder: (context) => _OfflineChartsSheet(box: box),
  );
}

/// Names an area by its centre, e.g. `39.47N 0.38W`. Coordinates travel better
/// than a reverse-geocoded place name: no network, no locale, and they mean
/// something to the person who framed the box.
String areaNameForBox(TileBox box) {
  final lat = (box.north + box.south) / 2;
  final lon = (box.east + box.west) / 2;
  final latLabel = '${lat.abs().toStringAsFixed(2)}${lat >= 0 ? 'N' : 'S'}';
  final lonLabel = '${lon.abs().toStringAsFixed(2)}${lon >= 0 ? 'E' : 'W'}';
  return '$latLabel $lonLabel';
}

class _OfflineChartsSheet extends ConsumerStatefulWidget {
  const _OfflineChartsSheet({required this.box});

  final TileBox box;

  @override
  ConsumerState<_OfflineChartsSheet> createState() =>
      _OfflineChartsSheetState();
}

class _OfflineChartsSheetState extends ConsumerState<_OfflineChartsSheet> {
  ChartDetail _detail = ChartDetail.standard;

  int _tileCount(ChartDetail detail) =>
      ChartRegionDownloader.plannedTileCount(widget.box, detail.maxZoom);

  String _estimate(AppLocalizations l, ChartDetail detail) {
    final tiles = _tileCount(detail);
    return l.chartAreaEstimate(
      tiles,
      ByteUtils.format(tiles * ChartRegionDownloader.estimatedTileBytes),
    );
  }

  Future<void> _start() async {
    final l = AppLocalizations.of(context)!;
    await ref.read(chartDownloadProvider.notifier).start(
          name: areaNameForBox(widget.box),
          box: widget.box,
          maxZoom: _detail.maxZoom,
        );
    if (!mounted) return;
    final phase = ref.read(chartDownloadProvider).phase;
    switch (phase) {
      case ChartDownloadPhase.done:
        NavisSnackbar.success(context, l.chartsDownloadDone);
      case ChartDownloadPhase.cancelled:
        NavisSnackbar.info(context, l.chartsDownloadCancelled);
      case ChartDownloadPhase.failed:
        NavisSnackbar.error(context, l.chartsDownloadFailed);
      case ChartDownloadPhase.idle:
      case ChartDownloadPhase.running:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final download = ref.watch(chartDownloadProvider);
    final storage = ref.watch(chartStorageBytesProvider).valueOrNull;
    final planned = _tileCount(_detail);
    final tooLarge = planned > ChartRegionDownloader.maxTilesPerRegion;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: Dimens.spaceXl,
          right: Dimens.spaceXl,
          top: Dimens.spaceXl,
          bottom: Dimens.spaceXl + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.download_for_offline_outlined,
                  color: AppColors.cyan,
                  size: Dimens.iconLg,
                ),
                const SizedBox(width: Dimens.spaceMd),
                Expanded(
                  child: Text(
                    l.offlineCharts,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: context.txtPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Dimens.spaceSm),
            Text(
              l.offlineChartsIntro,
              style: TextStyle(color: context.txtSecondary, fontSize: 13),
            ),
            const SizedBox(height: Dimens.spaceLg),
            for (final detail in ChartDetail.values) ...[
              NavisSelectableCard(
                title: switch (detail) {
                  ChartDetail.standard => l.chartDetailStandard,
                  ChartDetail.fine => l.chartDetailFine,
                },
                subtitle: _estimate(l, detail),
                icon: switch (detail) {
                  ChartDetail.standard => Icons.map_outlined,
                  ChartDetail.fine => Icons.zoom_in_map,
                },
                selected: _detail == detail,
                onTap: download.isRunning
                    ? () {}
                    : () => setState(() => _detail = detail),
              ),
              const SizedBox(height: Dimens.spaceSm),
            ],
            if (tooLarge) ...[
              const SizedBox(height: Dimens.spaceXs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.amber,
                    size: Dimens.iconSm,
                  ),
                  const SizedBox(width: Dimens.spaceSm),
                  Expanded(
                    child: Text(
                      l.chartAreaTooLarge,
                      style: const TextStyle(
                        color: AppColors.amber,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: Dimens.spaceLg),
            if (download.isRunning)
              _DownloadProgress(
                state: download,
                onCancel: ref.read(chartDownloadProvider.notifier).cancel,
              )
            else
              NavisButton(
                label: l.downloadThisArea,
                icon: Icons.download_rounded,
                isDisabled: tooLarge,
                onPressed: _start,
              ),
            const SizedBox(height: Dimens.spaceMd),
            Row(
              children: [
                if (storage != null)
                  Expanded(
                    child: Text(
                      l.chartStorageUsed(ByteUtils.format(storage)),
                      style: TextStyle(
                        color: context.txtSecondary,
                        fontSize: 12,
                      ),
                    ),
                  )
                else
                  const Spacer(),
                TextButton(
                  onPressed: () {
                    final router = GoRouter.of(context);
                    Navigator.of(context).pop();
                    router.push('/charts/offline');
                  },
                  child: Text(l.manageSavedAreas),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadProgress extends StatelessWidget {
  const _DownloadProgress({required this.state, required this.onCancel});

  final ChartDownloadState state;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${l.downloadingCharts} ${state.done}/${state.total}',
                style: TextStyle(color: context.txtPrimary, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: onCancel,
              child: Text(
                l.cancel,
                style: const TextStyle(color: AppColors.amber),
              ),
            ),
          ],
        ),
        const SizedBox(height: Dimens.spaceSm),
        ClipRRect(
          borderRadius: BorderRadius.circular(Dimens.radiusPill),
          child: LinearProgressIndicator(
            value: state.fraction,
            minHeight: 6,
            backgroundColor: context.glassBg,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.cyan),
          ),
        ),
      ],
    );
  }
}
