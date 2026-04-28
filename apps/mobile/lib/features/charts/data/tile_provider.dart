import 'package:flutter_map/flutter_map.dart';

import 'package:navis_mobile/features/charts/data/cached_tile_provider.dart';

class OpenSeaMapTileProvider {
  OpenSeaMapTileProvider._();

  static final _cachedProvider = CachedTileProvider();

  static TileLayer get baseLayer => TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.navis.mobile',
        maxZoom: 18,
        tileProvider: _cachedProvider,
      );

  static TileLayer get seamarkLayer => TileLayer(
        urlTemplate: 'https://tiles.openseamap.org/seamark/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.navis.mobile',
        maxZoom: 18,
        tileProvider: _cachedProvider,
      );
}
