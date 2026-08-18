import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:navis_mobile/features/charts/data/chart_tile_layer.dart';
import 'package:navis_mobile/features/charts/data/tile_math.dart';

/// Pulls raster tiles off the network. One place, so a tile fetched while
/// panning and a tile fetched by a region download are the same request with
/// the same headers — the store cannot end up with two flavours of the same
/// tile.
///
/// A tile server answers 404 (or an empty body) for "there is no tile here",
/// which is most of the seamark layer. That is a real answer: it comes back as
/// an empty list and gets stored as such, so we never ask again.
class ChartTileFetcher {
  ChartTileFetcher({Dio? client}) : _client = client ?? _defaultClient();

  final Dio _client;

  static Dio _defaultClient() {
    return Dio(
      BaseOptions(
        responseType: ResponseType.bytes,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 12),
        validateStatus: (status) => status == 200 || status == 404,
      ),
    );
  }

  /// Identifies the app to the tile servers, which reject anonymous traffic.
  /// flutter_map sets its own on the tile provider from
  /// `userAgentPackageName`; this is the fallback for the downloader, which
  /// has no layer to take one from.
  static const Map<String, String> defaultHeaders = {
    'User-Agent': 'navis-mobile (com.navis.mobile)',
  };

  Future<Uint8List> fetch(
    ChartTileLayer layer,
    TileRef ref, {
    Map<String, String>? headers,
  }) async {
    final response = await _client.get<List<int>>(
      layer.url(ref.z, ref.x, ref.y),
      options: Options(
        responseType: ResponseType.bytes,
        headers: (headers == null || headers.isEmpty)
            ? defaultHeaders
            : {...defaultHeaders, ...headers},
      ),
    );
    final data = response.data;
    if (response.statusCode == 404 || data == null || data.isEmpty) {
      return Uint8List(0);
    }
    return Uint8List.fromList(data);
  }
}
