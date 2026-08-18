import 'package:navis_mobile/features/charts/data/chart_tile_fetcher.dart';
import 'package:navis_mobile/features/charts/data/chart_tile_layer.dart';
import 'package:navis_mobile/features/charts/data/chart_tile_store.dart';
import 'package:navis_mobile/features/charts/data/tile_math.dart';
import 'package:navis_mobile/features/charts/domain/entities/chart_region.dart';

/// How far a region download has got. Reported as a whole so the UI never has
/// to add up partial counters.
typedef ChartDownloadTally = ({
  int done,
  int total,
  int bytes,
  int failures,
});

/// Why a download refused to start or stopped early.
enum ChartDownloadOutcome { completed, cancelled, tooManyFailures }

/// Fills the offline tile store for one [ChartRegion].
///
/// Both layers are fetched, shallowest zoom first, so an interrupted download
/// still leaves usable wide-area coverage instead of a detailed patch of
/// nothing. Tiles already on disk are skipped, which makes a re-run a resume.
class ChartRegionDownloader {
  ChartRegionDownloader({
    required this.store,
    ChartTileFetcher? fetcher,
    this.concurrency = 4,
  }) : fetcher = fetcher ?? ChartTileFetcher();

  final ChartTileStore store;
  final ChartTileFetcher fetcher;

  /// Parallel requests. Deliberately low: the public OSM/OpenSeaMap servers
  /// ask for at most a couple of connections, and a phone on a marina wifi is
  /// not the place to open twenty.
  final int concurrency;

  /// Default shallowest zoom for a new region — whole-coastline context for a
  /// few dozen tiles. The region itself carries the range that was used.
  static const int minZoom = 6;

  /// Ceiling per region, across both layers. Past this the download stops
  /// being a download and starts being a scrape.
  static const int maxTilesPerRegion = 12000;

  /// Rough average tile weight, for the size shown before downloading. Base
  /// tiles run 10-20 KB, seamark tiles far less.
  static const int estimatedTileBytes = 12 * 1024;

  /// Tiles this region needs, both layers, before skipping what is on disk.
  static int plannedTileCount(TileBox box, int maxZoom) {
    final perLayer = TileMath.countTiles(box, minZoom, maxZoom);
    return perLayer * ChartTileLayer.values.length;
  }

  static int estimatedBytes(TileBox box, int maxZoom) =>
      plannedTileCount(box, maxZoom) * estimatedTileBytes;

  /// Downloads [region], reporting progress through [onProgress] (throttled —
  /// twelve thousand rebuilds would cost more than the download).
  ///
  /// Returns how it ended. The region row is written before the first tile so
  /// an app kill mid-download leaves something to resume, and rewritten at the
  /// end with the tile count and size actually on disk.
  Future<ChartDownloadOutcome> download(
    ChartRegion region, {
    required void Function(ChartDownloadTally tally) onProgress,
    bool Function()? isCancelled,
  }) async {
    final box = (
      west: region.west,
      south: region.south,
      east: region.east,
      north: region.north,
    );
    final work = <({ChartTileLayer layer, TileRef ref})>[];
    for (final ref in TileMath.tiles(box, region.minZoom, region.maxZoom)) {
      for (final layer in ChartTileLayer.values) {
        work.add((layer: layer, ref: ref));
      }
    }

    await store.saveRegion(
      region.copyWith(status: ChartRegionStatus.downloading),
    );

    var next = 0;
    var done = 0;
    var bytes = 0;
    var failures = 0;
    var stopped = false;
    final total = work.length;

    void report() => onProgress(
          (done: done, total: total, bytes: bytes, failures: failures),
        );

    Future<void> worker() async {
      while (true) {
        if (stopped || (isCancelled?.call() ?? false)) return;
        if (next >= work.length) return;
        final item = work[next++];

        try {
          if (await store.has(item.layer, item.ref)) {
            done++;
          } else {
            final tileBytes = await fetcher.fetch(item.layer, item.ref);
            await store.save(item.layer, item.ref, tileBytes);
            bytes += tileBytes.length;
            done++;
          }
        } on Exception {
          failures++;
          // A handful of dropped tiles is a fact of life on a marina wifi and
          // leaves a usable chart. A sustained failure rate means the network
          // is gone (or the server is refusing us) and grinding through
          // thousands more requests would only waste the user's battery.
          if (failures > 40 && failures > total ~/ 5) {
            stopped = true;
            return;
          }
        }

        if ((done + failures) % 25 == 0) report();
      }
    }

    await Future.wait(
      List.generate(concurrency, (_) => worker(), growable: false),
    );

    final cancelled = isCancelled?.call() ?? false;
    final usage = await store.regionUsage(region);
    final outcome = stopped
        ? ChartDownloadOutcome.tooManyFailures
        : cancelled
            ? ChartDownloadOutcome.cancelled
            : ChartDownloadOutcome.completed;

    // A cancelled download keeps whatever it managed to store: those tiles
    // stay pinned and the map still draws them offline. Only a download that
    // ended with nothing on disk is a failure — there is no chart to show.
    final failed = total > 0 && usage.tiles == 0;

    await store.saveRegion(
      region.copyWith(
        tileCount: usage.tiles,
        bytes: usage.bytes,
        status: failed ? ChartRegionStatus.failed : ChartRegionStatus.ready,
      ),
    );
    report();
    return outcome;
  }
}
