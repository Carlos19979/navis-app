import 'package:flutter_map/flutter_map.dart';

class OpenSeaMapTileProvider {
  OpenSeaMapTileProvider._();

  static TileLayer get baseLayer => TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.navis.mobile',
        maxZoom: 18,
      );

  static TileLayer get seamarkLayer => TileLayer(
        urlTemplate: 'https://tiles.openseamap.org/seamark/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.navis.mobile',
        maxZoom: 18,
      );
}
