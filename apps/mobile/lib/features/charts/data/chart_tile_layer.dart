import 'package:navis_mobile/core/config/env.dart';

/// The two raster layers the charts are built from. The id is the storage key
/// in the offline tile store, so it must stay stable across releases.
enum ChartTileLayer {
  base('base', Env.chartTileUrl),
  seamark('seamark', Env.seamarkTileUrl);

  const ChartTileLayer(this.id, this.urlTemplate);

  final String id;
  final String urlTemplate;

  /// Fills `{z}/{x}/{y}` in [urlTemplate]. The store and the downloader build
  /// URLs through this so a cached tile and a downloaded tile are the same
  /// bytes from the same place.
  String url(int z, int x, int y) => urlTemplate
      .replaceAll('{z}', '$z')
      .replaceAll('{x}', '$x')
      .replaceAll('{y}', '$y');
}
