import 'dart:ui' show Color;

import 'package:flutter_map/flutter_map.dart';

import 'package:navis_mobile/features/charts/data/chart_tile_layer.dart';
import 'package:navis_mobile/features/charts/data/chart_tile_provider.dart';

/// The two chart layers, wired to the offline-first tile store.
class OpenSeaMapTileProvider {
  OpenSeaMapTileProvider._();

  /// One provider per layer, shared by every map in the app so they share one
  /// tile store and one HTTP client.
  static final _base = ChartTileProvider(layer: ChartTileLayer.base);
  static final _seamark = ChartTileProvider(layer: ChartTileLayer.seamark);

  /// Deepest zoom the tile servers publish.
  static const int maxTileZoom = 18;

  /// Painted behind every chart, so a tile that has not arrived reads as water
  /// rather than as the default dead grey. Matches the OSM sea fill, and it is
  /// the honest colour to guess at sea.
  static const Color waterBackground = Color(0xFFAAD3DF);

  /// [maxNativeZoom] is how the offline map keeps drawing when the user zooms
  /// past what was downloaded: flutter_map then requests the deepest available
  /// level and scales those tiles up. Blurry beats blank at sea. Leave it null
  /// online to get full detail.
  static TileLayer baseLayer({int? maxNativeZoom}) => TileLayer(
        urlTemplate: ChartTileLayer.base.urlTemplate,
        userAgentPackageName: 'com.navis.mobile',
        maxZoom: maxTileZoom.toDouble(),
        maxNativeZoom: maxNativeZoom ?? maxTileZoom,
        tileProvider: _base,
      );

  static TileLayer seamarkLayer({int? maxNativeZoom}) => TileLayer(
        urlTemplate: ChartTileLayer.seamark.urlTemplate,
        userAgentPackageName: 'com.navis.mobile',
        maxZoom: maxTileZoom.toDouble(),
        maxNativeZoom: maxNativeZoom ?? maxTileZoom,
        tileProvider: _seamark,
      );
}
