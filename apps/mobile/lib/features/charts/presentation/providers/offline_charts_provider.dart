import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/network/connectivity_provider.dart';
import 'package:navis_mobile/features/charts/data/chart_region_downloader.dart';
import 'package:navis_mobile/features/charts/data/chart_tile_store.dart';
import 'package:navis_mobile/features/charts/data/tile_math.dart';
import 'package:navis_mobile/features/charts/domain/entities/chart_region.dart';

/// The regions whose tiles are on this device.
final chartRegionsProvider =
    AsyncNotifierProvider<ChartRegionsNotifier, List<ChartRegion>>(
  ChartRegionsNotifier.new,
);

class ChartRegionsNotifier extends AsyncNotifier<List<ChartRegion>> {
  @override
  Future<List<ChartRegion>> build() =>
      ref.watch(chartTileStoreProvider).regions();

  Future<void> reload() async {
    state = AsyncData(await ref.read(chartTileStoreProvider).regions());
  }

  /// Deletes a region and frees its tiles. Optimistic: the row disappears at
  /// once and comes back if the delete fails.
  Future<void> delete(String id) async {
    final previous = state.valueOrNull ?? const <ChartRegion>[];
    state = AsyncData(previous.where((r) => r.id != id).toList());
    try {
      await ref.read(chartTileStoreProvider).deleteRegion(id);
    } on Exception {
      state = AsyncData(previous);
      rethrow;
    }
  }
}

/// Bytes the chart tiles occupy, downloaded regions and browse cache together.
final chartStorageBytesProvider = FutureProvider<int>((ref) async {
  // Recomputed whenever the region list changes — a download or a delete.
  ref.watch(chartRegionsProvider);
  return ref.watch(chartTileStoreProvider).totalBytes();
});

/// The deepest zoom that is on disk *everywhere* the user downloaded, or null
/// when online.
///
/// Fed to the tile layers as `maxNativeZoom`: offline, zooming past this level
/// keeps drawing (flutter_map upscales the deepest stored tiles) instead of
/// going blank. The minimum across regions rather than the maximum, so the
/// guarantee holds in the shallowest one too.
final offlineChartZoomProvider = Provider<int?>((ref) {
  if (ref.watch(connectivityProvider)) return null;
  final regions = ref.watch(chartRegionsProvider).valueOrNull;
  if (regions == null) return null;
  final usable = regions
      .where((r) => r.status != ChartRegionStatus.failed)
      .map((r) => r.maxZoom);
  if (usable.isEmpty) return null;
  return usable.reduce(math.min);
});

enum ChartDownloadPhase { idle, running, done, cancelled, failed }

/// Progress of the one download that can be in flight at a time.
final class ChartDownloadState {
  const ChartDownloadState({
    this.phase = ChartDownloadPhase.idle,
    this.regionName,
    this.done = 0,
    this.total = 0,
    this.bytes = 0,
  });

  final ChartDownloadPhase phase;
  final String? regionName;
  final int done;
  final int total;
  final int bytes;

  bool get isRunning => phase == ChartDownloadPhase.running;

  double get fraction => total == 0 ? 0 : math.min(1.0, done / total);

  ChartDownloadState copyWith({
    ChartDownloadPhase? phase,
    String? regionName,
    int? done,
    int? total,
    int? bytes,
  }) {
    return ChartDownloadState(
      phase: phase ?? this.phase,
      regionName: regionName ?? this.regionName,
      done: done ?? this.done,
      total: total ?? this.total,
      bytes: bytes ?? this.bytes,
    );
  }
}

/// Deliberately long-lived (not autoDispose): closing the download sheet — or
/// walking off the chart tab — must not abort a download in progress, the same
/// way trip recording survives leaving the map.
final chartDownloadProvider =
    StateNotifierProvider<ChartDownloadNotifier, ChartDownloadState>((ref) {
  return ChartDownloadNotifier(ref);
});

class ChartDownloadNotifier extends StateNotifier<ChartDownloadState> {
  ChartDownloadNotifier(this._ref) : super(const ChartDownloadState());

  final Ref _ref;
  bool _cancelRequested = false;

  void cancel() => _cancelRequested = true;

  /// Starts a download for [box] up to [maxZoom]. No-op while one is running.
  Future<void> start({
    required String name,
    required TileBox box,
    required int maxZoom,
  }) async {
    if (state.isRunning) return;
    _cancelRequested = false;

    final store = _ref.read(chartTileStoreProvider);
    final region = ChartRegion(
      id: 'region_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      west: box.west,
      south: box.south,
      east: box.east,
      north: box.north,
      minZoom: ChartRegionDownloader.minZoom,
      maxZoom: maxZoom,
      createdAt: DateTime.now(),
    );

    state = ChartDownloadState(
      phase: ChartDownloadPhase.running,
      regionName: name,
      total: ChartRegionDownloader.plannedTileCount(box, maxZoom),
    );

    try {
      final outcome = await ChartRegionDownloader(store: store).download(
        region,
        onProgress: (tally) {
          if (!mounted) return;
          state = state.copyWith(
            done: tally.done,
            total: tally.total,
            bytes: tally.bytes,
          );
        },
        isCancelled: () => _cancelRequested,
      );
      if (!mounted) return;
      state = state.copyWith(
        phase: switch (outcome) {
          ChartDownloadOutcome.completed => ChartDownloadPhase.done,
          ChartDownloadOutcome.cancelled => ChartDownloadPhase.cancelled,
          ChartDownloadOutcome.tooManyFailures => ChartDownloadPhase.failed,
        },
      );
    } on Exception {
      if (mounted) {
        state = state.copyWith(phase: ChartDownloadPhase.failed);
      }
    } finally {
      // Refresh the saved-areas list (and the storage figure that hangs off
      // it) however the download ended.
      if (mounted) await _ref.read(chartRegionsProvider.notifier).reload();
    }
  }
}
